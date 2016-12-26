import logging
import signal

from service_watcher.systemd import SystemdClient
from service_watcher.zookeeper import ZooKeeperClient


class Status(ZooKeeperClient, SystemdClient):
    def __init__(self, config_file):
        super(Status, self).__init__(config_file=config_file)

        # Inject the systemd client in services
        self.config.setup_systemd(self)

    def run(self):
        pass
