#!/bin/bash

# Fail if any command fail
set -e

# Load the shared provisioning script
source ./deploy_shared.sh

# Load flink setup parameters
source ./flink_shared.sh

FLINK_BASE_NAME="flink-1.1.3"

# Install Flink
if (($FORCE_INSTALL)) || ! [ -d $FLINK_INSTALL_DIR ]; then
  echo "Flink: Installing..."
  get_file "http://apache.mirrors.ovh.net/ftp.apache.org/dist/flink/flink-1.1.3/flink-1.1.3-bin-hadoop1-scala_2.10.tgz" "$FLINK_BASE_NAME.tgz"
  tar xf "$FLINK_BASE_NAME.tgz"
  rm -rf $FLINK_INSTALL_DIR
  mv $FLINK_BASE_NAME $FLINK_INSTALL_DIR
fi
