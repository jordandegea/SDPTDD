#!/usr/bin/python

import argparse
import logging
from service_watcher.monitor import Monitor
from service_watcher.status import Status

logging.basicConfig(level=logging.INFO)

parser = argparse.ArgumentParser(description="Twitter Weather ServiceWatcher")
parser.add_argument('action', metavar='action', choices=['monitor', 'status'],
                    help='the action the script should perform')
parser.add_argument('--config', dest='config_file', type=argparse.FileType('r'),
                    help='path to the config file to be used')

args = parser.parse_args()
if args.action == 'monitor':
    Monitor(args.config_file).run()
elif args.action == 'status':
    Status(args.config_file).run()