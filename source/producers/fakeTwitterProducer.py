import sys
from kafka import KafkaProducer
import random
import time


class FakeTwitterProducer(KafkaProducer):
    rate = 1.0 # tweets/sec
    allowance = rate
    last_check = time.clock()

    def __init__(self, rate, logging=False, **configs):
        super(FakeTwitterProducer, self).__init__(**configs)
        self.fake_tweet = open('fake_tweet.json', 'r').read()
        self.logging = logging
        self.rate = rate
        if logging:
            self.log_file = open('fake_tweet.log', 'w')

    def generate_tweet(self):
        return self.fake_tweet

    def run_producer(self):
        while True:
            current = time.clock()
            time_passed = current - self.last_check
            if time_passed >= self.rate:
                self.send_to_kafka(self.generate_tweet())
                self.last_check = current

    def send_to_kafka(self, tweet):
        self.send('twitter', self.fake_tweet.encode('utf-8'), b'Paris')
        # print tweet
        if self.logging:
            self.log_file.write(tweet)


if __name__ == "__main__":
    logging = False
    if len(sys.argv) > 3:
        print "Usage : python fake_twitter [--log]"
        exit(1)
    if '--log' in sys.argv:
        logging = True
        sys.argv.remove('--log')
    rate = sys.argv[1]

    FakeTwitterProducer(
        1/float(rate),
        logging,
        bootstrap_servers='localhost:1234',
        acks=0  # do not wait for acknowledgement
    ).run_producer()
