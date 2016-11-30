from tweepy.streaming import StreamListener
from tweepy import OAuthHandler
from tweepy import Stream
from kafka import KafkaProducer
from producer import Producer
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
    def __init__(self):
        super(TwitterProducer, self).__init__()
        self.producer = Producer()
        self.error_log = open("twitter_errors.log", "w")

    def on_data(self, data):
        self.producer.send_to_kafka(data)  # The key must be set
        return True

    def on_error(self, status):
        self.error_log.write(status)


if __name__ == '__main__':
    l = TwitterProducer()
    auth = OAuthHandler(consumer_key, consumer_secret)
    auth.set_access_token(access_token, access_token_secret)

    stream = Stream(auth, l)
    print l.producer.get_bounding_boxes()
    stream.filter(locations=l.producer.get_bounding_boxes()) # warning: 'locations' filter act as a OR with all other filters
