#!/bin/bash

# Fail if any command fail
set -e

# Load the shared provisioning script
source ./deploy_shared.sh

# Load flink setup parameters
source ./flink_shared.sh

# Deploy jar
cp files/KafkaHbaseBridge.jar ${FLINK_INSTALL_DIR}
cp files/FakeTwitterProducer.jar ${FLINK_INSTALL_DIR}
cp files/KafkaConsoleBridge.jar ${FLINK_INSTALL_DIR}
cp files/fake_tweet.json ${FLINK_INSTALL_DIR}

