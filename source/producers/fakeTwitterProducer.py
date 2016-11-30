import sys
from kafka import KafkaProducer
from producer import Producer
import random
import time


class FakeTwitterProducer(Producer):
    rate = 1.0 # tweets/sec
    allowance = rate
    last_check = time.clock()

    def __init__(self, rate, logging=False):
        Producer.__init__(self, logging)
        self.fake_tweet = open('fake_tweet.json', 'r').read()
        self.rate = rate

    def generate_tweet(self):
        return self.fake_tweet

    def run_producer(self):
        while True:
            current = time.clock()
            time_passed = current - self.last_check
            if time_passed >= self.rate:
                self.send_to_kafka(self.generate_tweet())
                self.last_check = current


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
        logging
    ).run_producer()
