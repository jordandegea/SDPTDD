import logging
import signal

from gi.repository import GLib

from service_watcher.systemd import SystemdClient
from service_watcher.zookeeper import ZooKeeperClient


class Monitor(ZooKeeperClient, SystemdClient):
    def __init__(self, config_file):
        super(Monitor, self).__init__(config_file=config_file)

        # Setup terminate handler
        signal.signal(signal.SIGTERM, self._on_sigterm)

        # Inject the systemd client in services
        self.config.setup_systemd(self)

    def run(self):
        logging.info("starting ServiceWatcher")

        # Connect to zookeeper
        self.start_zk()

        # Connect to systemd
        self.start_systemd(self._on_job_new)

        # Initially, all units must be stopped, because we are not the leader
        for service in self.config.services:
            service.initialize()

        # Start the main loop
        self.run_event_loop()

        # When exiting, shutdown all services
        for service in self.config.services:
            service.terminate()

        # Stop listening for events
        self.stop_systemd()

        # Leave ZooKeeper
        self.stop_zk()

    def _on_job_new(self, job_id, job_object_path, job_unit_name):
        logging.info("onJobNew %d %s %s" % ( job_id, job_object_path, job_unit_name ))
        try:
            job_object = self.get_object(job_object_path)
            logging.info("-> %d %s (%s) %s" % ( job_id, job_object.JobType, job_object.State, job_unit_name ))
        except GLib.Error:
            logging.error("failed getting job details for %d, unit is currently %s" % ( job_id, self.get_unit_by_name(job_unit_name).ActiveState ))

    def _on_sigterm(self, sig, frame):
        logging.warning("caught SIGTERM, trying to exit")
        self.stop_event_loop()
