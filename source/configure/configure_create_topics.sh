#!/bin/bash
# Pour chaque argument -t, crée le topic nommé par ce même argument dans Kafka

source ./deploy_shared.sh

while getopts ":vft:" arg; do
    case $arg in
        t)
        kafka-topics --create --zookeeper $(hostname):2181 --replication-factor 3 --partition 1 --topic $OPTARG
        ;;
    esac
done
