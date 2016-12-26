from socket import gethostname

from kazoo.recipe.party import ShallowParty

from service_watcher import service as svc
from service_watcher.systemd import SystemdClient
from service_watcher.zookeeper import ZooKeeperClient


class Status(ZooKeeperClient, SystemdClient):
    def __init__(self, config_file):
        super(Status, self).__init__(config_file=config_file)

        # Inject the systemd client in services
        self.config.setup_systemd(self)

    def run(self):
        self.start_zk()
        self.start_systemd()

        hostname = gethostname()
        for service in self.config.services:
            print("%s:" % service.name)

            party = ShallowParty(self.zk, "/service_watcher/active/%s" % service.name)
            failed_party = ShallowParty(self.zk, "/service_watcher/failed/%s" % service.name)

            if service.type == svc.GLOBAL:
                print("  type: global")
            elif service.type == svc.SHARED:
                print("  type: shared")
            elif service.type == svc.MULTI:
                print("  type: multi (unsupported)")

            if service.type != svc.MULTI:
                print("  global status:")
                print("    running on:")
                instances = 0
                total_instances = 0
                for member in party:
                    print("     %s %s" % ('*' if hostname == member else '-', member))
                    instances = instances + 1
                    total_instances = total_instances + 1

                print("    failed on:")
                for member in failed_party:
                    print("     %s %s" % ('*' if hostname == member else '-', member))
                    total_instances = total_instances + 1

                if service.type == svc.SHARED:
                    total_instances = service.count
                print("  summary:")
                print("    %d out of %d instances ok" % (instances, total_instances))
            print("")


        self.stop_systemd()
        self.stop_zk()

