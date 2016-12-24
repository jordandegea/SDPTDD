import yaml


class Config(object):
    def __init__(self, config_file):
        # Load config from input file
        self.config = yaml.load(config_file)

        # Convenience attribute
        self.services = self.config['services']
        self.zk_quorum = self.config['zookeeper']['quorum']
