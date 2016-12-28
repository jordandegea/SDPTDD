#!/bin/bash

# Fail if any command fail
set -e

# Load the shared provisioning script
source ./deploy_shared.sh

# Load flink setup parameters
source ./flink_shared.sh

# Deploy files
chown root:root -R files/*
mv files/KafkaHbaseBridge.jar $FLINK_INSTALL_DIR
mv files/FakeTwitterProducer.jar $FLINK_INSTALL_DIR
mv files/KafkaConsoleBridge.jar $FLINK_INSTALL_DIR
mv files/fake_tweet.json $FLINK_INSTALL_DIR

