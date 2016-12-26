import logging
import signal
import os
from gi.repository import GLib

from service_watcher.systemd import SystemdClient
from service_watcher.zookeeper import ZooKeeperClient
from service_watcher.control import ControlRoot


# https://stackoverflow.com/questions/26388088/python-gtk-signal-handler-not-working
def InitSignal(signals, callback):
    def signal_action(signal):
        callback()

    def idle_handler(*args):
        GLib.idle_add(signal_action, priority=GLib.PRIORITY_HIGH)

    def handler(*args):
        signal_action(args[0])

    def install_glib_handler(sig):
        unix_signal_add = None

        if hasattr(GLib, "unix_signal_add"):
            unix_signal_add = GLib.unix_signal_add
        elif hasattr(GLib, "unix_signal_add_full"):
            unix_signal_add = GLib.unix_signal_add_full

        if unix_signal_add:
            unix_signal_add(GLib.PRIORITY_HIGH, sig, handler, sig)
        else:
            logging.error("Can't install GLib signal handler, too old gi.")

    SIGS = [getattr(signal, s, None) for s in signals.split()]
    for sig in filter(None, SIGS):
        signal.signal(sig, idle_handler)
        GLib.idle_add(install_glib_handler, sig, priority=GLib.PRIORITY_HIGH)


class Monitor(ZooKeeperClient, SystemdClient):
    def __init__(self, config_file):
        super(Monitor, self).__init__(config_file=config_file)

        # Setup terminate handler
        InitSignal("SIGTERM", self.exit)

        # Inject the systemd client in services
        self.config.setup_systemd(self)

        # Build a lookup table for services
        self.services_lut = {}
        for service in self.config.services:
            self.services_lut[service.name] = service

    def run(self):
        logging.info("starting ServiceWatcher")

        # Connect to zookeeper
        self.start_zk()

        # Connect to systemd
        self.start_systemd(self.on_job_event)

        # Initially, all units must be stopped, because we are not the leader
        for service in self.config.services:
            service.initialize()

        # Start the control root for all services
        with ControlRoot(self.zk, self.config.services):
            # Start the main loop
            self.run_event_loop()

        # When exiting, shutdown all services
        for service in self.config.services:
            service.terminate()

        # Stop listening for events
        self.stop_systemd()

        # Leave ZooKeeper
        self.stop_zk()

    def on_job_event(self, job_id, job_object_path, job_unit_name, status):
        try:
            filename, ext = os.path.splitext(job_unit_name)
            unit_name = filename.split("@", 2)[0]
            self.services_lut[unit_name].on_job_event(job_id, job_object_path, filename, status)
        except KeyError:
            pass

    def exit(self):
        logging.warning("caught SIGTERM, trying to exit")
        self.stop_event_loop()
