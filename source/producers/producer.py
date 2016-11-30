from kafka import KafkaProducer
import yaml


class Producer():
    bootstrap_server = ''
    locations = {}

    def __init__(self, logging=False):
        self.logging = logging
        self.parse_yaml("config.yml")
        self.producer = KafkaProducer(
            bootstrap_servers=self.bootstrap_server,
            acks=0  # do not wait for acknowledgement
        )
        if self.logging:
            self.log_file = open("tweets.log", "w")

    def send_to_kafka(self, data):
        self.producer.send('twitter', data.encode('utf-8'))  # The key must be set
        if self.logging:
            self.log_file.write(data)

    def parse_yaml(self, fileName):
        with open(fileName, 'r') as stream:
            try:
                config = yaml.load(stream)
                locations = config['environment']['locations']
                for name in locations:
                    # Create a dict associating a bounding box to a name (eg Paris and its bounding box coordinates)
                    self.locations[name] = [ float(v) for v in locations[name].replace(' ', '').split(',') ]

                self.bootstrap_server = config['kafka']['bootstrap_server']

            except yaml.YAMLError as exc:
                print(exc)
                exit(1)

    def get_bounding_boxes(self):
        """
        We want all bounding boxes in a single list (so 4 successive values will define a bounding box). So basically
        We want to merge the dict of lists into a single list.
        """
        return [ v for l in self.locations for v in self.locations[l] ]
