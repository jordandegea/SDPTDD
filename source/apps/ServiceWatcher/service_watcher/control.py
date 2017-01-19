import json
import logging
import threading
from socket import gethostname

from gi.repository import GLib
from kazoo.recipe.partitioner import SetPartitioner
from kazoo.recipe.party import ShallowParty

from service_watcher import service as svc
from service_watcher.prestart import *


class ControlRoot(object):
    def __init__(self, zk, services, timings, tmpdir):
        super(ControlRoot, self).__init__()
        # ZooKeeper instance
        self.zk = zk
        # Timing properties
        self.timings = timings
        # The exit event to signal all control units should exit
        self.exit_event = threading.Event()
        # Create control groups for all shared services
        self.control_groups = [self.control_group(service) for service in services]
        # Default to stop services on exit
        self.reload_exit = False
        # Instance resolvers
        self.instance_resolvers = {}
        # Temporary directory
        self.tmpdir = tmpdir

    def control_group(self, service):
        if service.type == svc.GLOBAL:
            return GlobalControlGroup(self, service)
        elif service.type == svc.SHARED:
            return SharedControlGroup(self, service)
        elif service.type == svc.MULTI:
            return MultiControlGroup(self, service)

    def set_reload_mode(self):
        self.reload_exit = True

    def register_resolver(self, name, func):
        self.instance_resolvers[name] = func

    def instance_resolver_root(self, instance_name):
        if instance_name not in self.instance_resolvers:
            raise UnknownInstance()
        else:
            resolved = self.instance_resolvers[instance_name](instance_name)
            # logging.info("ControlRoot: resolving %s to %s" % (instance_name, resolved))
            return resolved

    def __enter__(self):
        for control_group in self.control_groups:
            control_group.prestart()

        for control_group in self.control_groups:
            control_group.start()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        # We are actively exiting
        self.exit_event.set()
        # Notify control groups they should exit
        for control_group in self.control_groups:
            control_group.stop()


class ControlGroup(object):
    def __init__(self, control_root, service):
        super(ControlGroup, self).__init__()
        # Root controller for this group
        self.control_root = control_root
        # The service definition for this control group
        self.service = service
        # this attribute is to be set by child instances
        # but we cannot pass it to the constructor as this induces a circular dependency
        self.unit = None

    def prestart(self):
        self.unit.prestart()

    def start(self):
        self.unit.start()

    def stop(self):
        self.unit.stop()


class ControlUnit(threading.Thread):
    def __init__(self, control_group, name):
        super(ControlUnit, self).__init__(name=name)
        # Parent control group
        self.control_group = control_group
        # Loop event, to throttle on events
        self.loop_event = threading.Event()

    def prestart(self):
        pass

    def stop(self):
        # Unblock the event loop
        self.release_loop()
        # Wait for the thread to terminate
        self.join()

    def release_loop(self):
        self.loop_event.set()

    def loop_tick(self, timeout=None):
        # Wait for the loop event to be set
        if self.loop_event.wait(timeout):
            # Reset the event
            self.loop_event.clear()

    def get_unit(self, param=None):
        return self.control_group.service.get_unit(param)

    def job_event_handler(self, job_id, job_object_path, status):
        self.release_loop()


class GlobalControlGroup(ControlGroup):
    def __init__(self, control_root, service):
        super(GlobalControlGroup, self).__init__(control_root, service)
        # Only valid on global services
        if self.service.type != svc.GLOBAL:
            raise ValueError("a global control group can only manage global services (at %s)" % service.name)
        # Store the reference to the managed unit instance
        self.unit = GlobalControlUnit(self)
        # Log the initialization event
        logging.info("%s: global control group initialized" % service.name)


class ServiceLogic(object):
    def __init__(self, zk, name, service, unit, control_root):
        super(ServiceLogic, self).__init__()
        self.name = name
        self.service = service
        self.unit = unit
        self.control_root = control_root

        # Group membership for this service object
        self.party = ShallowParty(zk, "/service_watcher/active/%s" % self.name, gethostname())
        self.failed_party = ShallowParty(zk, "/service_watcher/failed/%s" % self.name, gethostname())

        self.service_started = False
        self.service_start_initiated = False
        self.service_failed = False
        self.service_stop_initiated = False

        self.should_run = None
        self.joined_scheduled = False

        # Restore state of prestart
        self.retry_later_notified = False
        if self.service.prestart is not None:
            self.service.prestart.load_state(os.path.join(self.control_root.tmpdir, "%s.yml" % self.name))

    def set_should_run(self, value):
        self.should_run = value

    def tick(self):
        state = None
        exit_code = 0

        try:
            state = self.unit.ActiveState
            exit_code = self.unit.ExecMainCode
        except GLib.Error:
            logging.error("%s: failed getting state from systemd" % self.name)

        if exit_code == 143:
            try:
                self.unit.ResetFailed()
            except GLib.Error:
                logging.error("%s: failed resetting failed state of service (143)" % self.name)
            state = "inactive"

        # First step, update current state
        if state == "active":
            if not self.service_started:
                logging.info("%s: service started" % self.name)

                self.party.join()
                self.service_started = True
                self.service_start_initiated = False

            if self.service_failed:
                self.failed_party.leave()
                self.service_failed = False
        elif state == "inactive":
            if self.service_started:
                logging.info("%s: service stopped" % self.name)

                self.party.leave()
                self.service_started = False
                self.service_start_initiated = False
                self.service_stop_initiated = False

            if self.service_failed:
                self.failed_party.leave()
                self.service_failed = False
                self.service_start_initiated = False
                self.service_stop_initiated = False
        elif state == "failed":
            if self.service_started:
                self.party.leave()
                self.service_started = False
                self.service_start_initiated = False
                self.service_stop_initiated = False

            if not self.service_failed:
                logging.warning("%s: service failed, holding off" % self.name)

                self.failed_party.join()
                self.service_failed = True
                self.service_start_initiated = False
                self.service_stop_initiated = False

        # Only take a decision if we know the current state of the service and what we should do
        if state is not None:
            self.actions()

    def actions(self):
        try:
            self._actions()
        except:
            logging.error("%s: failed controlling the service" % self.name)

    def _actions(self):
        if self.should_run is not None:
            if self.should_run and not self.service_stop_initiated:
                # try having the service running
                if not self.service_started:
                    # run the pre-exec
                    def prestart_cb():
                        if self.service.prestart is not None:
                            try:
                                logging.debug("%s: executing prestart script" % self.name)
                                self.service.prestart.execute(self.control_root.instance_resolver_root)
                                self.retry_later_notified = False
                                return True
                            except RetryExecute:
                                if not self.retry_later_notified:
                                    logging.info("%s: retrying later, missing scheduled instance" % self.name)
                                    self.retry_later_notified = True
                            except Exception as e:
                                logging.error("%s: critical error in prestart script: %s" % (self.name, e))
                        else:
                            return True
                        return False

                    self.start_service(prestart_cb)
                else:
                    if self.service.prestart is not None and self.service.prestart.is_dirty(self.control_root.instance_resolver_root):
                        logging.info("%s: prestart script state is not up-to-date, restarting service" % self.name)
                        self.stop_service()
            elif self.should_run:
                # try having the service stopped
                if self.service_started:
                    self.stop_service()

    def terminate(self, reload_mode):
        if self.service.prestart is not None:
            self.service.prestart.save_state(os.path.join(self.control_root.tmpdir, "%s.yml" % self.name))

        if self.service_start_initiated or self.service_started:
            # the service is currently running
            if reload_mode:
                logging.info("%s: keeping service running for reload" % self.name)
            else:
                try:
                    self.stop_service()
                except:
                    logging.error("%s: error stopping service on terminate" % self.name)
        elif self.service_failed:
            # the service has failed
            if reload_mode:
                logging.warning("%s: resetting failed status for reload" % self.name)
                self.unit.ResetFailed()
            elif self.unit.ExecMainCode == 143:
                logging.warning("%s: resetting SIGTERM 143 exit" % self.name)
                self.unit.ResetFailed()
            else:
                logging.warning("%s: exiting with failed status" % self.name)

    def start_service(self, guard = None):
        if not self.service_start_initiated:
            if guard is None or guard():
                logging.info("%s: starting service" % self.name)
                self.unit.Start("fail")
                self.service_start_initiated = True

    def stop_service(self):
        if not self.service_stop_initiated:
            logging.info("%s: stopping service" % self.name)
            self.unit.Stop("fail")
            self.service_stop_initiated = True


class GlobalControlUnit(ControlUnit):
    def __init__(self, control_group):
        super(GlobalControlUnit, self).__init__(control_group, control_group.service.name)

    def prestart(self):
        # ZooKeeper instance
        self.zk = self.control_group.control_root.zk

        # Encapsulated logic for the managed global service
        self.sl = ServiceLogic(self.zk, self.control_group.service.name, self.control_group.service, self.get_unit(),
                               self.control_group.control_root)

        # Register the resolver for prestart scripts
        def resolver(target_name):
            raise ResolvingNotSupported()

        self.control_group.control_root.register_resolver(self.sl.name, resolver)

    def run(self):
        # Event to signal the thread should exit
        exit_event = self.control_group.control_root.exit_event

        # Get the reference to sl
        sl = self.sl

        # A global service should always run
        sl.set_should_run(True)

        # Main loop for this unit
        with self.control_group.service.handler(self.job_event_handler):
            while not exit_event.is_set():
                # Update the service object
                sl.tick()

                if sl.service_failed:
                    # There is no way to detect a service unit has been reset using systemctl
                    # So we must resort to polling here. But as this is an inexpensive local operation,
                    # and a particularly edgy case (global services should not be failed), we can do this
                    # anyways.
                    self.loop_tick(self.control_group.control_root.timings['failed_loop_tick'])
                else:
                    # wait for a new event
                    self.loop_tick()

        sl.terminate(self.control_group.control_root.reload_exit)


class SharedControlGroup(ControlGroup):
    def __init__(self, control_root, service):
        super(SharedControlGroup, self).__init__(control_root, service)
        # Only valid on shared services
        if self.service.type != svc.SHARED:
            raise ValueError("a shared control group can only manage shared services (at %s)" % service.name)
        # Create the control unit for this group
        self.unit = SharedControlUnit(self)
        # Log the initialization event
        logging.info("%s: shared control group initialized" % service.name)


class SharedControlUnit(ControlUnit):
    def __init__(self, control_group):
        # Initialize underlying thread
        # Note that the thread name is unique also in the ZooKeeper znode space
        super(SharedControlUnit, self).__init__(control_group, control_group.service.name)
        self.last_partition = None

    def prestart(self):
        # ZooKeeper instance
        self.zk = self.control_group.control_root.zk

        # Encapsulated logic for the managed shared service
        self.sl = ServiceLogic(self.zk, self.control_group.service.name, self.control_group.service, self.get_unit(),
                               self.control_group.control_root)

        # Register the resolver for prestart scripts
        def resolver(target_name):
            if target_name != self.control_group.service.name:
                raise UnknownInstance()

            if self.last_partition is None or len(self.last_partition) == 0:
                raise DelayPrestart()
            return ",".join(self.last_partition)

        self.control_group.control_root.register_resolver(self.sl.name, resolver)

    def run(self):
        # Event to signal the thread should exit
        exit_event = self.control_group.control_root.exit_event

        # Get the reference to sl and zk
        zk = self.zk
        sl = self.sl

        with self.control_group.service.handler(self.job_event_handler):
            # Loop forever
            while not exit_event.is_set():
                # The shared service for this unit is currently failed, so stay out of the partition waiting for the
                # unit to be reset
                sl.tick()

                if sl.service_failed:
                    self.loop_tick(self.control_group.control_root.timings['failed_loop_tick'])
                else:
                    # Create the partitioner
                    partitioner_path = "/service_watcher/partition/%s" % self.control_group.service.name
                    # Note that we use the service as a set for the partitioner, but as we use a custom partition_func,
                    # so this is ok
                    partitioner = SetPartitioner(zk, partitioner_path, self.control_group.service,
                                                 self.partition_func, gethostname(),
                                                 self.control_group.control_root.timings['partitioner_boundary'],
                                                 self.control_group.control_root.timings['partitioner_reaction'])
                    logging.info("%s: created partitioner at %s" % (self.name, partitioner_path))

                    try:
                        acquired = False

                        while not exit_event.is_set() and not partitioner.failed and not sl.service_failed:
                            # update service status from systemd
                            sl.tick()

                            if partitioner.release:
                                # immediately release set, we will perform a diff-update on the next acquire
                                logging.info("%s: releasing partitioner set" % self.name)
                                # note that we should now leave the service as-is, while waiting for what to do
                                sl.set_should_run(None)
                                # actually release the partition
                                partitioner.release_set()
                            elif partitioner.acquired:
                                # we have a new partition
                                new_p = list(partitioner)

                                if not acquired:
                                    logging.info("%s: acquired partition set" % self.name)
                                    acquired = True

                                # the service should run if the partition is non-empty
                                sl.set_should_run(len(new_p) > 0)

                                # force taking actions
                                sl.actions()

                                # wait for wake-up, but not too long so we are still responsive to
                                # partitioner events
                                self.loop_tick(self.control_group.control_root.timings['loop_tick'])
                            elif partitioner.allocating:
                                acquired = False
                                logging.info("%s: acquiring partition" % self.name)
                                partitioner.wait_for_acquire()
                    finally:
                        # Release the partitioner when leaving
                        partitioner.finish()
                        # No action should be taken
                        sl.set_should_run(None)
                        # Remove scheduled state
                        sl.tick()

        # When exiting, stop all services
        sl.terminate(self.control_group.control_root.reload_exit)

    def partition_func(self, identifier, members, service):
        # Sort members so we have a consistent order over all allocators
        sorted_members = sorted(members)
        allocation_state = {}
        target_members = []

        for member in sorted_members:
            allocation_state[member] = []

        # For the current param, allocate as much instances as possible
        # No worker should have to run the same service twice though
        for i in range(min(service.count, len(members))):
            member = sorted_members[i]
            allocation_state[member].append("%d" % i)
            target_members.append(member)

        self.last_partition = target_members
        logging.info("%s: computed partition %s" % (self.name, json.dumps(allocation_state)))
        logging.info("%s: resolver state %s" % (self.name, json.dumps(target_members)))

        # The resulting "partition" is the set of services for the current instance
        return allocation_state[identifier]


class MultiControlGroup(ControlGroup):
    def __init__(self, control_root, service):
        super(MultiControlGroup, self).__init__(control_root, service)
        # Only valid on MULTI services
        if service.type != svc.MULTI:
            raise ValueError("a multi control group can only manage multi services (at %s)" % service.name)
        # Create the control unit for this group
        self.unit = MultiControlUnit(self)
        # Log the initialization event
        logging.info("%s: multi control group initialized" % service.name)


class MultiControlUnit(ControlUnit):
    def __init__(self, control_group):
        super(MultiControlUnit, self).__init__(control_group, control_group.service.name)
        self.last_partition = None

    def param_job_handler(self, job_id, job_object_path, status, param):
        super(MultiControlUnit, self).job_event_handler(job_id, job_object_path, status)

    def prestart(self):
        # ZooKeeper instance
        self.zk = self.control_group.control_root.zk

        # List of service logics
        self.services = [ServiceLogic(self.zk, "%s@%s" % (self.name, s), self.control_group.service, self.get_unit(s),
                                      self.control_group.control_root)
                         for s in self.control_group.service.instances]

        # Register the resolver for prestart scripts
        def resolver(target_name):
            if self.last_partition is None:
                raise DelayPrestart()

            if target_name not in self.last_partition:
                raise UnknownInstance()

            if len(self.last_partition[target_name]) == 0:
                raise DelayPrestart()

            return ",".join(self.last_partition[target_name])

        for sl in self.services:
            self.control_group.control_root.register_resolver(sl.name, resolver)

    def run(self):
        # Event to signal the thread should exit
        exit_event = self.control_group.control_root.exit_event

        # ZooKeeper instance
        zk = self.zk

        # List of service logics
        services = self.services

        # Tick all services once
        for service in services:
            service.tick()

        # List of services that are known to fail, and are included in the partitioning identifier
        known_failed_services = [service.name.split("@")[1] for service in services if service.service_failed]

        with self.control_group.service.handler(self.param_job_handler):
            # Loop forever
            while not exit_event.is_set():
                # Create the partitioner
                partitioner_path = "/service_watcher/partition/%s" % self.control_group.service.name
                # Create the identifier
                identifier = "%s@%s" % (gethostname(), "@".join(known_failed_services))
                identifier_needs_update = False
                # Note that we use a set of tuples for the partitioner, but as we use a custom partition_func, so
                # this is ok
                partitioner = SetPartitioner(zk, partitioner_path, [[x[0], x[1]] for x in self.control_group.service.instances.items()],
                                             self.partition_func, identifier,
                                             self.control_group.control_root.timings['partitioner_boundary'],
                                             self.control_group.control_root.timings['partitioner_reaction'])
                logging.info("%s: created partitioner at %s" % (self.name, partitioner_path))

                try:
                    acquired = False

                    while not exit_event.is_set() and not partitioner.failed:
                        # update services
                        for service in services:
                            service.tick()

                            param = service.name.split("@")[1]
                            if service.service_failed and param not in known_failed_services:
                                known_failed_services.append(param)
                                identifier_needs_update = True
                            elif not service.service_failed and param in known_failed_services:
                                known_failed_services.remove(param)
                                identifier_needs_update = True

                        if identifier_needs_update:
                            break

                        if partitioner.release:
                            # immediately release set, we will perform a diff-update on the next acquire
                            logging.info("%s: releasing partitioner set" % self.name)
                            # service logics should take no action
                            for service in services:
                                service.set_should_run(None)
                            # actually release the partition
                            partitioner.release_set()
                        elif partitioner.acquired:
                            # we have a new set of services to run
                            new_p = [item.split("@")[0] for item in partitioner]

                            if not acquired:
                                logging.info("%s: acquired partition set" % self.name)
                                acquired = True

                            # update activation status
                            for service in services:
                                service.set_should_run(service.name.split("@")[1] in new_p)

                            # run actions
                            for service in services:
                                service.actions()

                            # wait for wake-up, but not too long so we are still responsive to
                            # partitioner events
                            self.loop_tick(self.control_group.control_root.timings['loop_tick'])
                        elif partitioner.allocating:
                            acquired = False
                            logging.info("%s: acquiring partition" % self.name)
                            partitioner.wait_for_acquire()
                finally:
                    # Release the partitioner when leaving
                    partitioner.finish()

        # When exiting, stop all services
        for service in services:
            service.terminate(self.control_group.control_root.reload_exit)

    def partition_func(self, identifier, members, partitions):
        # Sort members so we have a consistent order over all allocators
        sorted_members = list(sorted(members))
        sorted_partitions = list(sorted(partitions, key=lambda x:x[0]))
        allocation_state = {}
        allocation_params = {}
        allocated = {}
        target_members = {}

        for param, count in sorted_partitions:
            target_members["%s@%s" % (self.control_group.service.name, param)] = []

        for member in sorted_members:
            allocation_params[member] = {}
            allocation_state[member] = []
            allocated[member] = False

        allocations = []
        for part in sorted_partitions:
            if part[1] == 1:
                allocations.append("%s@1" % part[0])
                part[1] = 0

        services_left = True
        while services_left:
            services_left = False
            for service in sorted_partitions:
                if service[1] > 0:
                    allocations.append("%s@%d" % (service[0], service[1]))
                    service[1] -= 1
                    services_left = True

        current_member = 0
        for instance in allocations:
            param = instance.split("@")[0]

            next_current_member = current_member
            for i in range(len(sorted_members)):
                member_spec = sorted_members[(current_member + i) % len(sorted_members)]
                member_splitted = member_spec.split("@")
                member_failed = member_splitted[1:]

                if param not in member_failed:
                    # If running in exclusive mode for this service, do not allocate
                    # a service to a worker that already has another service from
                    # this pool allocated
                    if (not self.control_group.service.exclusive or not allocated[member_spec]) and \
                        param not in allocation_params[member_spec]:
                        allocated[member_spec] = True
                        allocation_state[member_spec].append(instance)
                        allocation_params[member_spec][param] = True
                        target_members["%s@%s" % (self.control_group.service.name, param)].append(member_splitted[0])
                        next_current_member += 1
                        break
            current_member = next_current_member

        self.last_partition = target_members
        logging.info("%s: computed partition %s" % (self.name, json.dumps(allocation_state)))
        logging.info("%s: resolver state %s" % (self.name, json.dumps(target_members)))

        # The resulting "partition" is the set of services for the current instance
        return allocation_state[identifier]
