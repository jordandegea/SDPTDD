import sys
import logging
import yaml
import time
from pydbus import SystemBus
from kazoo.client import KazooClient

# Setup logging for ZooKeeper
logging.basicConfig(level=logging.INFO)

# Load config
config = None
with open(sys.argv[2], "r") as config_file:
    config = yaml.load(config_file)

for service in config:
    logging.info("About to monitor " + service['name'])

# Load ZooKeeper
zk = KazooClient(hosts=sys.argv[1])

# Start the connection
zk.start()

# Connect to systemd
bus = SystemBus()
systemd = bus.get(".systemd1")

logging.info("ServiceWatcher connected to ZooKeeper!")

while True:
    for service in config:
        full_name = service['name'] + '.service'
        unit_object_name = systemd.LoadUnit(full_name)
        unit = bus.get(".systemd1", unit_object_name)
        logging.info(full_name + " is currently " + unit.ActiveState)
    time.sleep(5)

# Stop the connection
zk.stop()