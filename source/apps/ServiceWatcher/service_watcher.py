#!/usr/bin/python

import sys
from service_watcher.monitor import Monitor

if len(sys.argv) != 3:
    print("usage: python service_watcher.py zookeeper:port config.yml")
else:
    Monitor(sys.argv[1], sys.argv[2]).run()
