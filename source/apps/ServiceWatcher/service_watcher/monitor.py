import sys
import logging
import signal

from pydbus import SystemBus
from gi.repository import GLib
from kazoo.client import KazooClient

from service_watcher.config import Config

class Monitor:
    def __init__(self, zk_quorum, config_file, level=logging.INFO):
        # Setup logging
        logging.basicConfig(level=level)

        # Load config
        self.config = Config(config_file)

        # Initialize the main loop
        self.main_loop = GLib.MainLoop()

        # Setup terminate handler
        signal.signal(signal.SIGTERM, self._on_sigterm)

        # Initialize the ZK client
        self.zk = KazooClient(zk_quorum)

    def start_zk(self):
        self.zk.start()

    def stop_zk(self):
        self.zk.stop()

    def run(self):
        logging.info("starting ServiceWatcher")

        # Connect to zookeeper
        self.start_zk()
        logging.info("connected to ZooKeeper")

        # Connect to systemd
        self.start_systemd()
        logging.info("connected to systemd")

        # Initially, all units must be stopped, because we are not the leader
        for service in self.config.services:
            service_name = service['name']
            unit = self.get_unit_by_name(service_name)

            if unit.ActiveState == 'running':
                logging.info("%s should not be running yet" % service_name)
                unit.Stop()
            elif unit.ActiveState == 'failed':
                logging.info("resetting failed state of %s" % service_name)
                unit.ResetFailed()

        # Start the main loop
        try:
            self.main_loop.run()
        except KeyboardInterrupt:
            logging.warning("caught KeyboardInterrupt, quitting")
        except SystemExit:
            logging.warning("caught SystemExit, quitting")

        # Stop listening for events
        logging.info("disconnecting from systemd")
        self.stop_systemd()

        # Leave ZooKeeper
        logging.info("disconnecting from ZooKeeper")
        self.stop_zk()

    def start_systemd(self):
        # Get systemd object from the system bus
        self.bus = SystemBus()
        self.systemd = self.bus.get(".systemd1")

        # Ask for DBus notifications
        self.systemd.Subscribe()

        # Setup handler for new jobs
        self.systemd.JobNew.connect(self._on_job_new)

    def stop_systemd(self):
        # Stop listening for DBus notifications
        self.systemd.Unsubscribe()

    def get_unit_by_name(self, name):
        # Auto append .service
        if not name.endswith(".service"):
            name = "%s.service" % name
        # Get bus path
        unit_path = self.systemd.LoadUnit(name)
        # Return unit object from bus
        return self.bus.get(".systemd1", unit_path)

    def _on_job_new(self, job_id, job_object_path, job_unit_name):
        logging.info("onJobNew %d %s %s" % ( job_id, job_object_path, job_unit_name ))
        try:
            job_object = self.bus.get(".systemd1", job_object_path)
            logging.info("-> %d %s (%s) %s" % ( job_id, job_object.JobType, job_object.State, job_unit_name ))
        except GLib.Error:
            logging.error("failed getting job details for %d, unit is currently %s" % ( job_id, self.get_unit_by_name(job_unit_name).ActiveState ))

    def _on_sigterm(self, sig, frame):
        logging.warning("caught SIGTERM, trying to exit")
        sys.exit()
