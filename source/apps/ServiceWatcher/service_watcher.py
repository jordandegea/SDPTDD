#!/usr/bin/python

import argparse
import logging
from service_watcher.controller import Controller
from service_watcher.status import Status

parser = argparse.ArgumentParser(description="Twitter Weather ServiceWatcher")
parser.add_argument('action', metavar='action', choices=['controller', 'status'],
                    help='the action the script should perform')
parser.add_argument('--config', dest='config_file', type=argparse.FileType('r'),
                    help='path to the config file to be used')

args = parser.parse_args()
if args.action == 'controller':
    logging.basicConfig(level=logging.INFO)
    Controller(args.config_file).run()
elif args.action == 'status':
    logging.basicConfig(level=logging.WARNING)
    Status(args.config_file).run()
