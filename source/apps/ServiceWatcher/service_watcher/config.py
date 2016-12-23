import yaml

class Config:
    def __init__(self, config_file):
        # Load config from YAML file
        with open(config_file, "r") as cf:
            self.config = yaml.load(cf)

        # Convenience attribute
        self.services = self.config
