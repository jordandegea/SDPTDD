#!/bin/bash
# Pour chaque argument -t, crée le topic nommé par ce même argument dans Kafka

source ./deploy_shared.sh

EXISTING_TOPICS=$(kafka-topics --list --zookeeper $(hostname):2181)

while getopts ":vft:" arg; do
    case $arg in
        t)
            if ! grep "$OPTARG" <<< "$EXISTING_TOPICS" > /dev/null ; then
                kafka-topics --create --zookeeper $(hostname):2181 --replication-factor 3 --partition 1 --topic $OPTARG
            else
                echo "Topic $OPTARG already exists."
            fi
            kafka-topics --zookeeper $(hostname):2181 --alter --topic "$OPTARG" --config retention.ms=60000
        ;;
    esac
done
