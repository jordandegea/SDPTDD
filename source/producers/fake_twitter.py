import sys
import random

class Fake_Twitter():
    def __init__(self, logging = False):
        self.fake_tweet = open('fake_tweet.json', 'r').read()
        self.logging = logging
        if logging:
            self.log_file = open('fake_tweet.log', 'w')

    def generateTweet(self):
        return self.fake_tweet

    def run_producer(self):
        while True:
            self.sendToKafka(self.generateTweet())

    def sendToKafka(self, tweet):
        print tweet
        if self.logging:
            self.log_file.write(tweet)


if __name__ == "__main__":
    if len(sys.argv) > 2:
        print "Usage : python fake_twitter [--log]"
        exit(1)
    if len(sys.argv) == 2:
        if "--log" != sys.argv[1]:
            print "Usage : python fake_twitter [--log]"
            exit(1)
        else:
            Fake_Twitter(True).run_producer()
    else:
            Fake_Twitter().run_producer()