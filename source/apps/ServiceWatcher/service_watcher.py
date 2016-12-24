#!/usr/bin/python

import argparse
import logging
from service_watcher.monitor import Monitor

logging.basicConfig(level=logging.INFO)

parser = argparse.ArgumentParser(description="Twitter Weather ServiceWatcher")
parser.add_argument('action', metavar='action', choices=['monitor'],
                    help='the action the script should perform')
parser.add_argument('--config', dest='config_file', type=argparse.FileType('r'),
                    help='path to the config file to be used')

args = parser.parse_args()
if args.action == 'monitor':
    Monitor(args.config_file).run()