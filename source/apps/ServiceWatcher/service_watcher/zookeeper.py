import logging
from kazoo.client import KazooClient

from service_watcher.roles import Configurable

class ZooKeeperClient(Configurable):
    def __init__(self, *args, **kwargs):
        super(ZooKeeperClient, self).__init__(*args, **kwargs)

        # Initialize the ZK client
        self.zk = KazooClient(self.config.zk_quorum)

    def start_zk(self):
        self.zk.start()
        logging.info("connected to ZooKeeper")

    def stop_zk(self):
        logging.info("disconnecting from ZooKeeper")
        self.zk.stop()
