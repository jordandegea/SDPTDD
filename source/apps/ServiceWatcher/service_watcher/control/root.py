import threading

from service_watcher import service as svc
from service_watcher.prestart import *

from service_watcher.control.global_group import GlobalControlGroup
from service_watcher.control.shared_group import SharedControlGroup
from service_watcher.control.multi_group import MultiControlGroup


class ControlRoot(object):
    def __init__(self, zk, services, timings, tmpdir):
        super(ControlRoot, self).__init__()
        # ZooKeeper instance
        self.zk = zk
        # Timing properties
        self.timings = timings
        # The exit event to signal all control units should exit
        self.exit_event = threading.Event()
        # Create control groups for all shared services
        self.control_groups = [self.control_group(service) for service in services]
        # Default to stop services on exit
        self.reload_exit = False
        # Instance resolvers
        self.instance_resolvers = {}
        # Temporary directory
        self.tmpdir = tmpdir

    def control_group(self, service):
        if service.type == svc.GLOBAL:
            return GlobalControlGroup(self, service)
        elif service.type == svc.SHARED:
            return SharedControlGroup(self, service)
        elif service.type == svc.MULTI:
            return MultiControlGroup(self, service)

    def set_reload_mode(self):
        self.reload_exit = True

    def register_resolver(self, name, func):
        self.instance_resolvers[name] = func

    def instance_resolver_root(self, instance_name):
        if instance_name not in self.instance_resolvers:
            raise UnknownInstance(instance_name)
        else:
            resolved = self.instance_resolvers[instance_name](instance_name)
            # logging.info("ControlRoot: resolving %s to %s" % (instance_name, resolved))
            return resolved

    def __enter__(self):
        for control_group in self.control_groups:
            control_group.prestart()

        for control_group in self.control_groups:
            control_group.start()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        # We are actively exiting
        self.exit_event.set()
        # Notify control groups they should exit
        for control_group in self.control_groups:
            control_group.stop()
