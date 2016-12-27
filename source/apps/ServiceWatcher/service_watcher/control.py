import json
import logging
import threading
from socket import gethostname

from gi.repository import GLib
from kazoo.recipe.partitioner import SetPartitioner
from kazoo.recipe.party import ShallowParty

from service_watcher import service as svc


class ControlRoot(object):
    def __init__(self, zk, services):
        super(ControlRoot, self).__init__()
        # ZooKeeper instance
        self.zk = zk
        # The exit event to signal all control units should exit
        self.exit_event = threading.Event()
        # Create control groups for all shared services
        self.control_groups = [self.control_group(service) for service in services]
        # Default to stop services on exit
        self.reload_exit = False

    def control_group(self, service):
        if service.type == svc.GLOBAL:
            return GlobalControlGroup(self, service)
        elif service.type == svc.SHARED:
            return SharedControlGroup(self, service)
        elif service.type == svc.MULTI:
            return MultiControlGroup(self, service)

    def set_reload_mode(self):
        self.reload_exit = True

    def __enter__(self):
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


class ControlUnit(threading.Thread):
    def __init__(self, control_group, name):
        super(ControlUnit, self).__init__(name=name)
        # Parent control group
        self.control_group = control_group
        # Loop event, to throttle on events
        self.loop_event = threading.Event()

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


class SimpleControlGroup(ControlGroup):
    def __init__(self, control_root, service):
        super(SimpleControlGroup, self).__init__(control_root, service)
        # this attribute is to be set by child instances
        # but we cannot pass it to the constructor as this induces a circular dependency
        self.unit = None

    def start(self):
        self.unit.start()

    def stop(self):
        self.unit.stop()


class GlobalControlGroup(SimpleControlGroup):
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
    def __init__(self, zk, name, service, unit):
        super(ServiceLogic, self).__init__()
        self.name = name
        self.service = service
        self.unit = unit

        # Group membership for this service object
        self.party = ShallowParty(zk, "/service_watcher/active/%s" % self.name, gethostname())
        self.failed_party = ShallowParty(zk, "/service_watcher/failed/%s" % self.name, gethostname())

        self.service_started = False
        self.service_start_initiated = False
        self.service_failed = False
        self.service_stop_initiated = False

        self.should_run = None

    def tick(self):
        state = None

        try:
            state = self.unit.ActiveState
        except GLib.Error:
            logging.error("%s: failed getting state from systemd" % self.name)

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
        try:
            if state is not None:
                self.actions()
        except GLib.Error:
            logging.error("%s: failed controlling the service" % self.name)

    def actions(self):
        if self.should_run is not None:
            if self.should_run:
                # try having the service running
                if not self.service_started:
                    self.start_service()
            else:
                # try having the service stopped
                if self.service_started:
                    self.stop_service()

    def terminate(self, reload_mode):
        if self.service_start_initiated or self.service_started:
            # the service is currently running
            if reload_mode:
                logging.info("%s: keeping service running for reload" % self.name)
            else:
                self.stop_service()
        elif self.service_failed:
            # the service has failed
            if reload_mode:
                logging.warning("%s: resetting failed status for reload" % self.name)
                self.unit.ResetFailed()
            else:
                logging.warning("%s: exiting with failed status" % self.name)

    def start_service(self):
        if not self.service_start_initiated:
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

    def run(self):
        # Event to signal the thread should exit
        exit_event = self.control_group.control_root.exit_event

        # ZooKeeper instance
        zk = self.control_group.control_root.zk

        # Encapsulated logic for the managed global service
        svc = ServiceLogic(zk, self.control_group.service.name, self.control_group.service, self.get_unit())

        # A global service should always run
        svc.should_run = True

        # Main loop for this unit
        with self.control_group.service.handler(self.job_event_handler):
            while not exit_event.is_set():
                # Update the service object
                svc.tick()

                if svc.service_failed:
                    # There is no way to detect a service unit has been reset using systemctl
                    # So we must resort to polling here. But as this is an inexpensive local operation,
                    # and a particularly edgy case (global services should not be failed), we can do this
                    # anyways.
                    self.loop_tick(5.0)
                else:
                    # wait for a new event
                    self.loop_tick()

        svc.terminate(self.control_group.control_root.reload_exit)


class SharedControlGroup(SimpleControlGroup):
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

    def run(self):
        # Event to signal the thread should exit
        exit_event = self.control_group.control_root.exit_event

        # ZooKeeper instance
        zk = self.control_group.control_root.zk

        # Encapsulated logic for the managed shared service
        svc = ServiceLogic(zk, self.control_group.service.name, self.control_group.service, self.get_unit())

        with self.control_group.service.handler(self.job_event_handler):
            # Loop forever
            while not exit_event.is_set():
                # Create the partitioner
                partitioner_path = "/service_watcher/partition/%s" % self.control_group.service.name
                # Note that we use the service as a set for the partitioner, but as we use a custom partition_func, so
                # this is ok
                partitioner = SetPartitioner(zk, partitioner_path, self.control_group.service,
                                             self.partition_func, gethostname(), 5)  # 5s time boundary
                logging.info("%s: created partitioner at %s" % (self.name, partitioner_path))

                try:
                    acquired = False

                    while not exit_event.is_set() and not partitioner.failed:
                        # update service status from systemd
                        svc.tick()

                        if partitioner.release:
                            # immediately release set, we will perform a diff-update on the next acquire
                            logging.info("%s: releasing partitioner set" % self.name)
                            # note that we should now leave the service as-is, while waiting for what to do
                            svc.should_run = None
                            # actually release the partition
                            partitioner.release_set()
                        elif partitioner.acquired:
                            # we have a new partition
                            new_p = list(partitioner)

                            if not acquired:
                                logging.info("%s: acquired partition set" % self.name)
                                acquired = True

                            # the service should run if the partition is non-empty
                            svc.should_run = len(new_p) > 0

                            # force taking actions
                            svc.actions()

                            # wait for wake-up, but not too long so we are still responsive to
                            # partitioner events
                            self.loop_tick(1.0)
                        elif partitioner.allocating:
                            acquired = False
                            logging.info("%s: acquiring partition" % self.name)
                            partitioner.wait_for_acquire()
                finally:
                    # Release the partitioner when leaving
                    partitioner.finish()

        # When exiting, stop all services
        svc.terminate(self.control_group.control_root.reload_exit)

    def partition_func(self, identifier, members, service):
        # Sort members so we have a consistent order over all allocators
        sorted_members = sorted(members)
        allocation_state = {}

        for member in sorted_members:
            allocation_state[member] = []

        # For the current param, allocate as much instances as possible
        # No worker should have to run the same service twice though
        for i in range(min(service.count, len(members))):
            allocation_state[sorted_members[i]].append("%d" % i)

        logging.info("%s: computed partition %s" % (self.name, json.dumps(allocation_state)))

        # The resulting "partition" is the set of services for the current instance
        return allocation_state[identifier]


class MultiControlGroup(SimpleControlGroup):
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

    def run(self):
        # Event to signal the thread should exit
        exit_event = self.control_group.control_root.exit_event

        # ZooKeeper instance
        zk = self.control_group.control_root.zk

        # List of service logics
        services = [ServiceLogic(zk, "%s@%s" % (self.name, s), self.control_group.service, self.get_unit(s)) for s in
                    self.control_group.service.instances]

        with self.control_group.service.handler(self.job_event_handler):
            # Loop forever
            while not exit_event.is_set():
                # Create the partitioner
                partitioner_path = "/service_watcher/partition/%s" % self.control_group.service.name
                # Note that we use a set of tuples for the partitioner, but as we use a custom partition_func, so
                # this is ok
                partitioner = SetPartitioner(zk, partitioner_path, self.control_group.service.instances.items(),
                                             self.partition_func, gethostname(), 5)  # 5s time boundary
                logging.info("%s: created partitioner at %s" % (self.name, partitioner_path))

                try:
                    acquired = False

                    while not exit_event.is_set() and not partitioner.failed:
                        # update services
                        for service in services:
                            service.tick()

                        if partitioner.release:
                            # immediately release set, we will perform a diff-update on the next acquire
                            logging.info("%s: releasing partitioner set" % self.name)
                            # service logics should take no action
                            for service in services:
                                service.should_run = None
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
                                service.should_run = service.name.split("@")[1] in new_p
                                service.actions()

                            # wait for wake-up, but not too long so we are still responsive to
                            # partitioner events
                            self.loop_tick(1.0)
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

    def partition_func(self, identifier, members, set):
        # Sort members so we have a consistent order over all allocators
        sorted_members = sorted(members)
        allocation_state = {}

        for member in sorted_members:
            allocation_state[member] = []

        for param, count in set:
            # For the current param, allocate as much instances as possible
            # No worker should have to run the same service twice though
            for i in range(min(count, len(members))):
                allocation_state[sorted_members[i]].append("%s@%d" % (param, i))

        logging.info("%s: computed partition %s" % (self.name, json.dumps(allocation_state)))

        # The resulting "partition" is the set of services for the current instance
        return allocation_state[identifier]
