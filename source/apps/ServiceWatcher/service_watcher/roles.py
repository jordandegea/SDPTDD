from service_watcher.config import Config

class Configurable(object):
    def __init__(self, *args, **kwargs):
        super(Configurable, self).__init__()

        # Initialize config
        self.config = Config(kwargs['config_file'])
