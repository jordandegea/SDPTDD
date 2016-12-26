from socket import gethostname

from kazoo.recipe.party import ShallowParty

from service_watcher import service as svc
from service_watcher.zookeeper import ZooKeeperClient


class Status(ZooKeeperClient):
    def __init__(self, config_file):
        super(Status, self).__init__(config_file=config_file)

    def run(self):
        self.start_zk()

        hostname = gethostname()
        for service in self.config.services:
            print("%s:" % service.name)

            if service.type == svc.GLOBAL:
                print("  type: global")
            elif service.type == svc.SHARED:
                print("  type: shared")
            elif service.type == svc.MULTI:
                print("  type: multi")

            if service.type != svc.MULTI:
                self.print_service_status(hostname, service, service.name)
            else:
                for instance in sorted(service.instances):
                    self.print_service_status(hostname, service, "%s@%s" % (service.name, instance))

            print("")

        self.stop_zk()

    def print_service_status(self, hostname, service, instance_name):
        party = ShallowParty(self.zk, "/service_watcher/active/%s" % instance_name)
        failed_party = ShallowParty(self.zk, "/service_watcher/failed/%s" % instance_name)

        print("  %s global status:" % instance_name)
        print("    running on:")
        instances = 0
        total_instances = 0
        for member in sorted(party):
            print("     %s %s" % ('*' if hostname == member else '-', member))
            instances = instances + 1
            total_instances = total_instances + 1
        print("    failed on:")
        for member in sorted(failed_party):
            print("     %s %s" % ('*' if hostname == member else '-', member))
            total_instances = total_instances + 1
        if service.type == svc.SHARED:
            total_instances = service.count
        print("  summary:")
        print("    %d out of %d instances ok" % (instances, total_instances))
