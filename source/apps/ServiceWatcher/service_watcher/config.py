import yaml

from service_watcher.service import Service


class Config(object):
    def __init__(self, config_file):
        super(Config, self).__init__()
        self.config_file_path = config_file.name
        config_file.close()

    def load(self):
        with open(self.config_file_path, "r") as config_file:
            # Load config from input file
            self.config = yaml.load(config_file)

        # Convenience attribute
        self.services = [Service(service) for service in self.config['services']]
        self.zk_quorum = self.config['zookeeper']['quorum']

    def setup_systemd(self, systemd_client):
        for service in self.services:
            service.setup_systemd(systemd_client)
