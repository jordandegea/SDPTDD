from tweepy.streaming import StreamListener
from tweepy import OAuthHandler
from tweepy import Stream
from kafka import KafkaProducer
import yaml

# Go to http://apps.twitter.com and create an app.
# The consumer key and secret will be generated for you after
consumer_key = "EXQ8uIU0Y39HfHxXxmlFPOqVI"
consumer_secret = "qZ3LSx62jFQW84PhrYmJJxaS3OHs093wjIgbwzrHPapRV8WuKm"

# After the step above, you will be redirected to your app's page.
# Create an access token under the the "Your access token" section
access_token = "730398860540051456-kzb8h3yz2gC33IaMAMEjYTL94bVAsqC"
access_token_secret = "Wmcf2Qfil0LkSYDJJ97c0sUbIoBpWtn7F03Kf6ac3amUk"


class TwitterProducer(StreamListener):
    locations = dict()
    bootstrap_server = ''

    def __init__(self):
        super(TwitterProducer, self).__init__()
        self.parse_yaml("../config.yml")
        self.producer = KafkaProducer(
            bootstrap_servers=self.bootstrap_server,
            acks=0  # do not wait for acknowledgement
        )

    def on_data(self, data):
        self.producer.send('twitter', data)  # The key must be set
        # print data
        return True

    def on_error(self, status):
        print(status)

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


if __name__ == '__main__':
    l = TwitterProducer()
    auth = OAuthHandler(consumer_key, consumer_secret)
    auth.set_access_token(access_token, access_token_secret)

    stream = Stream(auth, l)
    stream.filter(locations=l.get_bounding_boxes()) # warning: 'locations' filter act as a OR with all other filters
