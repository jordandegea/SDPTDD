import logging
import threading
import json
from gi.repository import GLib
from socket import gethostname
from service_watcher import service as svc
from kazoo.recipe.election import Election
from kazoo.recipe.party import ShallowParty
from kazoo.recipe.partitioner import SetPartitioner


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

    def get_unit(self):
        return self.control_group.service.get_unit()

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


class GlobalControlUnit(ControlUnit):
    def __init__(self, control_group):
        super(GlobalControlUnit, self).__init__(control_group, control_group.service.name)

    def run(self):
        # Event to signal the thread should exit
        exit_event = self.control_group.control_root.exit_event

        # ZooKeeper instance
        zk = self.control_group.control_root.zk

        # Group membership for this object (service-wise)
        party = ShallowParty(zk, "/service_watcher/active/%s" % self.control_group.service.name, gethostname())
        failed_party = ShallowParty(zk, "/service_watcher/failed/%s" % self.control_group.service.name, gethostname())

        # Main loop for this unit
        with self.control_group.service.handler(self.job_event_handler):
            service_started = False
            service_start_initiated = False
            service_failed = False

            while not exit_event.is_set():
                try:
                    state = self.get_unit().ActiveState

                    if state == "active":
                        if not service_started:
                            logging.info("%s: global service started" % self.name)
                            party.join()
                            service_started = True
                            service_start_initiated = False

                        if service_failed:
                            service_failed = False
                            service_start_initiated = False
                            failed_party.leave()
                    elif state == "inactive":
                        if service_started:
                            logging.info("%s: global service stopped" % self.name)
                            party.leave()
                            service_started = False
                            service_start_initiated = False

                        if service_failed:
                            service_failed = False
                            service_start_initiated = False
                            failed_party.leave()
                    elif state == "failed":
                        if service_started:
                            party.leave()
                            service_started = False
                            service_start_initiated = False

                        if not service_failed:
                            logging.warning("%s: global service failed, not starting until reset" % self.name)
                            failed_party.join()
                            service_failed = True
                            service_start_initiated = False

                    if not service_started:
                        # service not started yet
                        if not service_failed and not service_start_initiated:
                            # try starting the service
                            service_start_initiated = True
                            logging.info("%s: trying to start global service" % self.name)
                            self.get_unit().Start("fail")

                    if service_failed:
                        # There is no way to detect a service unit has been reset using systemctl
                        # So we must resort to polling here. But as this is an inexpensive local operation,
                        # and a particularly edgy case (global services should not be failed), we can do this
                        # anyways.
                        self.loop_tick(5.0)
                    else:
                        # wait for a new event
                        self.loop_tick()
                except GLib.Error:
                    logging.warning("%s: an error occurred while operating systemd" % self.name)

            if service_started or service_start_initiated:
                if self.control_group.control_root.reload_exit:
                    logging.info("%s: keeping the service running for reload" % self.name)
                else:
                    try:
                        logging.info("%s: stopping global service on exit" % self.name)
                        self.get_unit().Stop("fail")
                    except GLib.Error:
                        logging.warning("%s: an error occurred while stopping service on exit" % self.name)


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

        # List of currently activated services
        activated_service = False
        party = ShallowParty(zk, "/service_watcher/active/%s" % self.control_group.service.name, gethostname())
        failed_party = ShallowParty(zk, "/service_watcher/failed/%s" % self.control_group.service.name, gethostname())

        # Detect if the unit is already active
        if self.control_group.service.get_unit().ActiveState == "active":
            logging.info("%s: unit was already running" % self.name)
            party.join()
            activated_service = True

        # Loop forever
        while not exit_event.is_set():
            # Create the partitioner
            partitioner_path = "/service_watcher/partition/%s" % self.control_group.service.name
            # Note that we use the service as a set for the partitioner, but as we use a custom partition_func, this is ok
            partitioner = SetPartitioner(zk, partitioner_path, self.control_group.service,
                                         self.partition_func, gethostname(), 5) # 5s time boundary
            logging.info("%s: created partitioner at %s" % (self.name, partitioner_path))

            try:
                acquired = False

                while not exit_event.is_set() and not partitioner.failed:
                    if partitioner.release:
                        # immediately release set, we will perform a diff-update on the next acquire
                        logging.info("%s: releasing partitioner set" % self.name)
                        partitioner.release_set()
                    elif partitioner.acquired:
                        # we have a new partition
                        new_p = list(partitioner)

                        if not acquired:
                            logging.info("%s: acquired partition set" % self.name)
                            acquired = True

                        # is the partition non-empty?
                        if len(new_p) > 0:
                            if not activated_service:
                                logging.info("%s: starting service" % self.name)
                                self.control_group.service.get_unit().Start("fail")
                                activated_service = True
                                party.join()
                        else:
                            if activated_service:
                                logging.info("%s: stopping service" % self.name)
                                self.control_group.service.get_unit().Stop("fail")
                                activated_service = False
                                party.leave()

                        # wait for wake-up, but not too long so we are still responsive to
                        # partitioner events
                        self.loop_tick(1)
                    elif partitioner.allocating:
                        acquired = False
                        logging.info("%s: acquiring partition" % self.name)
                        partitioner.wait_for_acquire()
            finally:
                # Release the partitioner when leaving
                partitioner.finish()

        # When exiting, stop all services
        if activated_service:
            if self.control_group.control_root.reload_exit:
                logging.info("%s: keeping service running for reload" % self.name)
            else:
                try:
                    party.leave()
                    self.control_group.service.get_unit().Stop("fail")
                except:
                    logging.error("%s: error while stopping service" % self.name)

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

        # List of currently activated services
        activated_services = {}

        # Start with services that are already active
        for service in self.control_group.service.instances:
            unit = self.control_group.service.get_unit(service)
            if unit.ActiveState == "active":
                logging.info("%s: unit %s was already running" % (self.name, service))
                activated_services[service] = ShallowParty(zk, "/service_watcher/active/%s@%s" % (self.name, service), gethostname())
                activated_services[service].join()

        # Loop forever
        while not exit_event.is_set():
            # Create the partitioner
            partitioner_path = "/service_watcher/partition/%s" % self.control_group.service.name
            # Note that we use a set of tuples for the partitioner, but as we use a custom partition_func, this is ok
            partitioner = SetPartitioner(zk, partitioner_path, self.control_group.service.instances.items(),
                                         self.partition_func, gethostname(), 5) # 5s time boundary
            logging.info("%s: created partitioner at %s" % (self.name, partitioner_path))

            try:
                acquired = False

                while not exit_event.is_set() and not partitioner.failed:
                    if partitioner.release:
                        # immediately release set, we will perform a diff-update on the next acquire
                        logging.info("%s: releasing partitioner set" % self.name)
                        partitioner.release_set()
                    elif partitioner.acquired:
                        # we have a new set of services to run
                        new_p = [item.split("@")[0] for item in partitioner]

                        if not acquired:
                            logging.info("%s: acquired partition set" % self.name)
                            acquired = True

                        # first activate all services that need to be activated
                        for service in new_p:
                            if not service in activated_services:
                                # this is a new service that needs to be activated
                                logging.info("%s: starting instance %s" % (self.name, service))
                                self.control_group.service.get_unit(service).Start("fail")
                                activated_services[service] = ShallowParty(zk, "/service_watcher/active/%s@%s" % (self.name, service), gethostname())
                                activated_services[service].join()

                        # then stop all outdated services
                        removed_services = []
                        for service in activated_services:
                            if not service in new_p:
                                # this is a service that we should no longer run
                                logging.info("%s: stopping instance %s" % (self.name, service))
                                activated_services[service].leave()
                                removed_services.append(service)
                                self.control_group.service.get_unit(service).Stop("fail")

                        # clean up dictionary after iteration
                        for service in removed_services:
                            del activated_services[service]

                        # wait for wake-up, but not too long so we are still responsive to
                        # partitioner events
                        self.loop_tick(1)
                    elif partitioner.allocating:
                        acquired = False
                        logging.info("%s: acquiring partition" % self.name)
                        partitioner.wait_for_acquire()
            finally:
                # Release the partitioner when leaving
                partitioner.finish()

        # When exiting, stop all services
        for service in activated_services:
            if self.control_group.control_root.reload_exit:
                logging.info("%s: keeping %s service running for reload" % (self.name, service))
            else:
                try:
                    activated_services[service].leave()
                    self.control_group.service.get_unit(service).Stop("fail")
                except:
                    logging.error("%s: error while stopping instance %s" % (self.name, service))

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
