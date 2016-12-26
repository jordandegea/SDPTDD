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
        self.control_groups = [ControlGroup(self, service) for service in services if service.type == svc.SHARED]

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
        # Only valid on shared services
        if self.service.type != svc.SHARED:
            raise ValueError("cannot setup a control group on a non-shared service")
        # The semaphore that only allows one control unit
        self.semaphore = threading.BoundedSemaphore()
        # Create the instances
        self.units = [ControlUnit(self, i + 1) for i in range(service.count)]

    def start(self):
        # Start all threads
        for unit in self.units:
            unit.start()

    def stop(self):
        # Join all threads
        for unit in self.units:
            unit.stop()


class ControlUnit(threading.Thread):
    def __init__(self, control_group, instance_id = 1):
        # Initialize underlying thread
        # Note that the thread name is unique also in the ZooKeeper znode space
        super(ControlUnit, self).__init__(name=("%s_%d" % (control_group.service.name, instance_id)))
        # Initialize attributes
        self.control_group = control_group
        self.instance_id = instance_id
        # Loop event, to throttle on events
        self.loop_event = threading.Event()

    def stop(self):
        # Unblock the loop
        if self.election is not None:
            self.election.cancel()
        self.release_loop()
        # Wait for the thread to terminate
        self.join()

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
            logging.info("%s: chosen as main instance for service" % self.name)

            # We acquired the group semaphore, which means this is the only instance running for this service
            # Join the party for this service
            party.join()
            try:
                # Start the service
                self.get_unit().Start("fail")
                service_started = False
                service_failed = False

                with self.control_group.service.handler(self.job_event_handler):
                    # Now run an infinite loop
                    while not self.control_group.control_root.exit_event.is_set() and not service_failed:
                        unit_status = self.get_unit().ActiveState
                        logging.info("%s: currently %s" % (self.name, unit_status))

                        # Check for initial service start
                        if not service_started and unit_status == "active":
                            service_started = True
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
            # Leave the party for this service
            party.leave()
            # Release the semaphore
            self.control_group.semaphore.release()

    def job_event_handler(self, job_id, job_object_path, status):
        self.release_loop()

    def release_loop(self):
        self.loop_event.set()

    def loop_tick(self):
        # Wait forever for the loop event to be set
        self.loop_event.wait()
        # Reset the event
        self.loop_event.clear()

    def get_unit(self):
        return self.control_group.service.get_unit()