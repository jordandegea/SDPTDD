import logging
from pydbus import SystemBus
from gi.repository import GLib

class SystemdClient(object):
    def __init__(self, *args, **kwargs):
        super(SystemdClient, self).__init__()

        # Initialize the main loop
        self.main_loop = GLib.MainLoop()
        self.systemd_subscribed = False

    def start_systemd(self, job_new_notification = None):
        # Get systemd object from the system bus
        self.bus = SystemBus()
        self.systemd = self.bus.get(".systemd1")

        if job_new_notification is not None:
            self.systemd_subscribed = True

            # Setup handler for new jobs
            self.systemd.JobNew.connect(job_new_notification)

        # Notify systemd is ready
        logging.info("connected to systemd")

    def run_event_loop(self):
        if self.systemd_subscribed:
            # Ask for DBus notifications
            self.systemd.Subscribe()

        try:
            self.main_loop.run()
        except KeyboardInterrupt:
            logging.warning("caught KeyboardInterrupt, quitting")
        except SystemExit:
            logging.warning("caught SystemExit, quitting")

        if self.systemd_subscribed:
            # Stop listening for DBus notifications
            self.systemd.Unsubscribe()

    def stop_event_loop(self):
        self.main_loop.quit()

    def stop_systemd(self):
        logging.info("disconnecting from systemd")
        # nothing to do in fact

    def get_object(self, path):
        return self.bus.get(".systemd1", path)

    def get_unit_by_name(self, name):
        # Auto append .service
        if not name.endswith(".service"):
            name = "%s.service" % name
        # Get bus path
        unit_path = self.systemd.LoadUnit(name)
        # Return unit object from bus
        return self.get_object(unit_path)
