import logging
import threading
from gi.repository import GLib
from socket import gethostname
from service_watcher import service as svc
from kazoo.recipe.election import Election
from kazoo.recipe.party import ShallowParty


class ControlRoot(object):
    def __init__(self, zk, services):
        super(ControlRoot, self).__init__()
        # ZooKeeper instance
        self.zk = zk
        # The exit event to signal all control units should exit
        self.exit_event = threading.Event()
        # Create control groups for all shared services
        self.control_groups = [self.control_group(service) for service in services]

    def control_group(self, service):
        if service.type == svc.GLOBAL:
            return GlobalControlGroup(self, service)
        elif service.type == svc.SHARED:
            return SharedControlGroup(self, service)

    def __enter__(self):
        for control_group in self.control_groups:
            control_group.start()

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


class GlobalControlGroup(ControlGroup):
    def __init__(self, control_root, service):
        super(GlobalControlGroup, self).__init__(control_root, service)
        # Only valid on global services
        if self.service.type != svc.GLOBAL:
            raise ValueError("cannot setup a global control group on a shared service")
        # Create the control unit
        self.unit = GlobalControlUnit(self)

    def start(self):
        self.unit.start()

    def stop(self):
        self.unit.stop()


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
                            logging.warning("%s: global service failed" % self.name)
                            failed_party.join()
                            service_failed = True
                            service_start_initiated = False

                    if not service_started:
                        # service not started yet
                        if service_failed:
                            logging.warning("%s: not starting global service until reset" % self.name)
                        elif not service_start_initiated:
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
                try:
                    logging.info("%s: stopping global service on exit" % self.name)
                    self.get_unit().Stop("fail")
                except GLib.Error:
                    logging.warning("%s: an error occurred while stopping service on exit" % self.name)


class SharedControlGroup(ControlGroup):
    def __init__(self, control_root, service):
        super(SharedControlGroup, self).__init__(control_root, service)
        # Only valid on shared services
        if self.service.type != svc.SHARED:
            raise ValueError("cannot setup a shared control group on a global service")
        # The semaphore that only allows one control unit
        self.semaphore = threading.BoundedSemaphore()
        # Create the instances
        self.units = [SharedControlUnit(self, i + 1) for i in range(service.count)]

    def start(self):
        # Start all threads
        for unit in self.units:
            unit.start()

    def stop(self):
        # Join all threads
        for unit in self.units:
            unit.stop()


class SharedControlUnit(ControlUnit):
    def __init__(self, control_group, instance_id=1):
        # Initialize underlying thread
        # Note that the thread name is unique also in the ZooKeeper znode space
        super(SharedControlUnit, self).__init__(control_group, "%s_%d" % (control_group.service.name, instance_id))

    def stop(self):
        # Unblock the loop
        if self.election is not None:
            self.election.cancel()
        super(SharedControlUnit, self).stop()

    def run(self):
        # Event to signal the thread should exit
        exit_event = self.control_group.control_root.exit_event

        # ZooKeeper instance
        zk = self.control_group.control_root.zk

        # The leader election object
        election = Election(zk, "/service_watcher/election/%s" % self.name, gethostname())
        self.election = election

        # Group membership for this object (service-wise)
        party = ShallowParty(zk, "/service_watcher/active/%s" % self.control_group.service.name, gethostname())

        # Main loop for this unit
        while not exit_event.is_set():
            logging.info("%s: running for election" % self.name)
            # Run for election, see callback for the rest
            election.run(self.on_election, party)

    def on_election(self, party):
        logging.info("%s: elected as the leader" % self.name)

        # We are now the leader for the monitored instance
        if self.control_group.semaphore.acquire(False):
            # We acquired the group semaphore, which means this is the only instance running for this service
            logging.info("%s: chosen as main instance for service" % self.name)

            service_started = False

            try:
                # Start the service
                self.get_unit().Start("fail")
                service_failed = False

                with self.control_group.service.handler(self.job_event_handler):
                    # Now run an infinite loop
                    while not self.control_group.control_root.exit_event.is_set() and not service_failed:
                        unit_status = self.get_unit().ActiveState
                        logging.info("%s: currently %s" % (self.name, unit_status))

                        # Check for initial service start
                        if not service_started and unit_status == "active":
                            service_started = True
                            # Join the party for this service
                            party.join()
                            # Note it in the logs
                            logging.info("%s: systemd service started" % self.name)

                        # Check for failed status
                        if unit_status == "failed":
                            service_failed = True
                            logging.warning("%s: systemd service failed, abandoning leadership" % self.name)

                        # Check for inactive: manually killed for scheduling?
                        if service_started and unit_status == "inactive":
                            service_failed = True
                            logging.warning("%s: systemd service inactive, abandoning leadership" % self.name)

                        # Throttle infinite loop, unless we are about to exit
                        if not service_failed:
                            self.loop_tick()

                logging.info("%s: about to leave leadership for service" % self.name)

                # Stop service when exiting
                if service_started and not service_failed:
                    self.get_unit().Stop("fail")
            except GLib.Error:
                logging.error("%s: generic systemd error, abandoning leadership" % self.name)

            if service_started:
                # Leave the party for this service
                party.leave()
            # Release the semaphore
            self.control_group.semaphore.release()
