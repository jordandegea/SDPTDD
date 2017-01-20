from kazoo.handlers.threading import KazooTimeoutError
from kazoo.recipe.party import ShallowParty
from tabulate import tabulate

from service_watcher import service as svc
from service_watcher.control.utils import KNOWN_PARTIES
from service_watcher.roles import Configurable
from service_watcher.zookeeper import ZooKeeperClient


class Status(Configurable, ZooKeeperClient):
    def __init__(self, config_file):
        super(Status, self).__init__(config_file=config_file)
        # Initialize attributes
        self.current_service = None
        self.is_first_row = False
        self.current_table = None
        self.current_row = None

    def set_current_service(self, service):
        self.current_service = service
        self.is_first_row = True

    def begin_table(self):
        self.current_table = []
        self.current_row = None

    def begin_row(self):
        self.end_row()

        if self.is_first_row:
            t = ["global", "shared", "multi"][self.current_service.type]
            if hasattr(self.current_service, 'exclusive') and self.current_service.exclusive:
                t = "%s (exclusive)" % t

            n = self.current_service.name
            if not self.current_service.enabled:
                n = "%s (disabled)" % n

            self.current_row = [n, t]
            self.is_first_row = False
        else:
            self.current_row = ["", ""]

    def add_field(self, field):
        self.current_row.append(field)

    def end_row(self):
        if self.current_row is not None:
            self.current_table.append(self.current_row)
            self.current_row = None

    def out_table(self):
        self.end_row()
        print(tabulate(self.current_table, headers=["name", "type", "instance"] + KNOWN_PARTIES + ["health"],
                       tablefmt="grid"))
        self.current_table = None

    def run(self):
        self.config.load()

        try:
            self.start_zk(self.config.zk_quorum)
        except KazooTimeoutError:
            # No need to warn about error, Kazoo already logs it
            exit(2)

        # Prepare the output table
        self.begin_table()

        # Get the status of all services
        for service in self.config.services:
            # Set the info for the current service
            self.set_current_service(service)

            if service.type != svc.MULTI:
                self.begin_row()
                # Print service status
                self.print_service_status(service, service.name)
            else:
                # Print service status for each instance
                for instance in sorted(service.instances):
                    self.begin_row()
                    self.print_service_status(service, "%s@%s" % (service.name, instance))

        # Print the table
        self.out_table()

        self.stop_zk()

    def print_service_status(self, service, instance_name):
        # Create parties
        parties = {}
        for party in KNOWN_PARTIES:
            parties[party] = sorted(list(ShallowParty(self.zk, "/service_watcher/%s/%s" % (party, instance_name))))

        # Name of the current service instance
        self.add_field(instance_name)

        # List parties
        for party in KNOWN_PARTIES:
            self.add_field(", ".join(parties[party]))

        # Health status
        total_instances = len(parties['active']) + len(parties['failed'])
        if service.type == svc.SHARED:
            total_instances = service.count
        elif service.type == svc.MULTI:
            total_instances = service.instances[instance_name.split("@")[1]]

        self.add_field("%d / %d ok" % (len(parties['active']), total_instances))
