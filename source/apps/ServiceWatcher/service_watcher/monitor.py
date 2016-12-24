import logging
import signal

from service_watcher.systemd import SystemdClient
from service_watcher.zookeeper import ZooKeeperClient


class Monitor(ZooKeeperClient, SystemdClient):
    def __init__(self, config_file):
        super(Monitor, self).__init__(config_file=config_file)

        # Setup terminate handler
        signal.signal(signal.SIGTERM, self._on_sigterm)

        # Inject the systemd client in services
        self.config.setup_systemd(self)

        # Build a lookup table for services
        self.services_lut = {}
        for service in self.config.services:
            self.services_lut[service.unit_name] = service

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
        try:
            self.services_lut[job_unit_name].on_job_new(job_id, job_object_path)
        except KeyError:
            pass

    def _on_sigterm(self, sig, frame):
        logging.warning("caught SIGTERM, trying to exit")
        self.stop_event_loop()
