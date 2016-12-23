import sys
import logging
import yaml
import time
import signal
from pydbus import SystemBus
from gi.repository import GLib
from kazoo.client import KazooClient

def run():
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
    logging.info("ServiceWatcher connected to ZooKeeper!")

    # Connect to systemd
    bus = SystemBus()
    systemd = bus.get(".systemd1")

    def get_unit_by_name(full_name):
        return bus.get(".systemd1", systemd.LoadUnit(full_name))

    # Listen for job events
    systemd.Subscribe()
    def onJobNew(job_id, job_object, job_unit):
        logging.info("onJobNew %d %s %s" % ( job_id, job_object, job_unit ))
        try:
            job_object = bus.get(".systemd1", job_object)
            logging.info("-> %d %s (%s) %s" % ( job_id, job_object.JobType, job_object.State, job_unit ))
        except GLib.Error:
            logging.error("failed getting job details for %d, unit is currently %s" % ( job_id, get_unit_by_name(job_unit).ActiveState ))

    systemd.JobNew.connect(onJobNew)

    try:
        GLib.MainLoop().run()
    except KeyboardInterrupt:
        logging.info("caught KeyboardInterrupt, quitting properly")
    except SystemExit:
        logging.info("caught SystemExit, quitting properly")

    # Stop listening for job events
    systemd.Unsubscribe()

    # Stop the connection when exiting
    zk.stop()

def quit_handler(*args):
    GLib.MainLoop().quit()

# Setup logging
logging.basicConfig(level=logging.INFO)

# Handle termination
signal.signal(signal.SIGTERM, quit_handler)

run()
