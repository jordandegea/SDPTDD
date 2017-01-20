import logging

from service_watcher import service as svc
from service_watcher.control.base_group import ControlGroup, ControlUnit
from service_watcher.control.utils import ServiceLogic

from service_watcher.prestart import *


class GlobalControlGroup(ControlGroup):
    def __init__(self, control_root, service):
        super(GlobalControlGroup, self).__init__(control_root, service)
        # Only valid on global services
        if self.service.type != svc.GLOBAL:
            raise ValueError("a global control group can only manage global services (at %s)" % service.name)
        # Store the reference to the managed unit instance
        self.unit = GlobalControlUnit(self)
        # Log the initialization event
        logging.info("%s: global control group initialized" % service.name)


class GlobalControlUnit(ControlUnit):
    def __init__(self, control_group):
        super(GlobalControlUnit, self).__init__(control_group, control_group.service.name)
        # Initialize attributes
        self.zk = None
        self.sl = None

    def prestart(self):
        # ZooKeeper instance
        self.zk = self.control_group.control_root.zk

        # Encapsulated logic for the managed global service
        self.sl = ServiceLogic(self.zk, self.control_group.service.name, self.control_group.service, self.get_unit(),
                               self.control_group.control_root)

        # Register the resolver for prestart scripts
        # noinspection PyUnusedLocal
        def resolver(target_name):
            raise ResolvingNotSupported()

        self.control_group.control_root.register_resolver(self.sl.name, resolver)

    def run(self):
        # Event to signal the thread should exit
        exit_event = self.control_group.control_root.exit_event

        # Get the reference to sl
        sl = self.sl

        # A global service should always run
        sl.set_should_run(True)

        # Main loop for this unit
        with self.control_group.service.handler(self.job_event_handler):
            while not exit_event.is_set():
                # Update the service object
                sl.tick()

                if sl.service_failed:
                    # There is no way to detect a service unit has been reset using systemctl
                    # So we must resort to polling here. But as this is an inexpensive local operation,
                    # and a particularly edgy case (global services should not be failed), we can do this
                    # anyways.
                    self.loop_tick(self.control_group.control_root.timings['failed_loop_tick'])
                else:
                    # wait for a new event
                    self.loop_tick()

        sl.terminate(self.control_group.control_root.reload_exit)
