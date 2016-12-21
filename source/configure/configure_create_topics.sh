#!/bin/bash

source ./deploy_shared.sh

while getopts ":t:" arg; do
    case $arg in
        t)
        kafka-topics --create --zookeeper $(hostname):2181 --replication-factor 3 --partition 1 --topic $OPTARG
        ;;
    esac
done
