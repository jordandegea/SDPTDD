import logging

from kazoo.client import KazooClient
from kazoo.handlers.threading import SequentialThreadingHandler


class ZooKeeperClient(object):
    def __init__(self, *args, **kwargs):
        super(ZooKeeperClient, self).__init__()
        self.zk = None

    def start_zk(self, zk_quorum):
        # Initialize the ZK client
        self.zk = KazooClient(zk_quorum, handler=SequentialThreadingHandler())
        self.zk.start()
        logging.info("connected to ZooKeeper")

    def stop_zk(self):
        logging.info("disconnecting from ZooKeeper")
        self.zk.stop()
        self.zk = None
