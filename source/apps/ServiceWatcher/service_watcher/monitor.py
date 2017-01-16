import logging
import signal
import os
from gi.repository import GLib

from service_watcher.systemd import SystemdClient
from service_watcher.zookeeper import ZooKeeperClient
from service_watcher.control import ControlRoot
from service_watcher.roles import Configurable


# https://stackoverflow.com/questions/26388088/python-gtk-signal-handler-not-working
def InitSignal(signals, callback):
    def signal_action(signal):
        callback(signal)

    def idle_handler(*args):
        GLib.idle_add(signal_action, priority=GLib.PRIORITY_HIGH)
        return True

    def handler(*args):
        signal_action(args[0])
        return True

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

    for sig in signals:
        signal.signal(sig, idle_handler)
        install_glib_handler(sig)


class Monitor(Configurable, ZooKeeperClient, SystemdClient):
    def __init__(self, config_file):
        super(Monitor, self).__init__(config_file=config_file)

        # Setup terminate and reload handler
        InitSignal([15, 1], self.signal_callback) # SIGTERM, SIGHUP
        self.reload_signaled = False

    def run(self):
        logging.info("starting ServiceWatcher")

        # Create temporary directory
        tmpdir = "/tmp/service_watcher"
        if not os.path.isdir(tmpdir):
            os.mkdir(tmpdir)

        run_loop = True
        while run_loop:
            self.config.load()

            # Inject the systemd client in services
            self.config.setup_systemd(self)

            # Build a lookup table for services
            self.services_lut = {}
            for service in self.config.services:
                self.services_lut[service.name] = service

            # Connect to zookeeper
            self.start_zk(self.config.zk_quorum)

            # Connect to systemd
            self.start_systemd(self.on_job_event)

            # Start the control root for all services
            with ControlRoot(self.zk, self.config.services, self.config.timings, tmpdir) as cr:
                # Start the main loop
                self.run_event_loop()

                if self.reload_signaled:
                    cr.set_reload_mode()
                    self.reload_signaled = False
                else:
                    run_loop = False

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

    def signal_callback(self, sgn):
        if sgn == 15: # SIGTERM
            self.exit()
        elif sgn == 1: # SIGHUP
            self.reload()

    def exit(self):
        logging.warning("caught SIGTERM, trying to exit")
        self.stop_event_loop()

    def reload(self):
        logging.warning("caught SIGHUP, exiting for reload")
        self.reload_signaled = True
        self.stop_event_loop()
