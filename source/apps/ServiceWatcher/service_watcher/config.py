import yaml

from service_watcher.service import Service


class Config(object):
    def __init__(self, config_file):
        super(Config, self).__init__()
        self.config_file_path = config_file.name
        config_file.close()
        # Initialize attributes
        self.config = {}
        self.services = []
        self.zk_quorum = None
        self.timings = {}

    def load(self):
        with open(self.config_file_path, "r") as config_file:
            # Load config from input file
            self.config = yaml.load(config_file)

        # Convenience attribute
        self.services = [Service(service) for service in self.config['services']]
        self.zk_quorum = self.config['zookeeper']['quorum']

        if 'timings' in self.config['zookeeper']:
            self.timings = self.config['zookeeper']['timings']
        else:
            self.timings = {}

        # Fix timing defaults
        if 'loop_tick' not in self.timings:
            self.timings['loop_tick'] = 1.0
        if 'failed_loop_tick' not in self.timings:
            self.timings['failed_loop_tick'] = 5.0
        if 'partitioner_boundary' not in self.timings:
            self.timings['partitioner_boundary'] = 5.0
        if 'partitioner_reaction' not in self.timings:
            self.timings['partitioner_reaction'] = 1.0

    def setup_systemd(self, systemd_client):
        for service in self.services:
            service.setup_systemd(systemd_client)
