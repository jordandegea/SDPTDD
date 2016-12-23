#!/bin/bash

# Fail if any command fail
set -eo pipefail

# Load the shared provisioning script
source ./deploy_shared.sh

# Load flink setup parameters
source ./service_watcher_shared.sh

echo "ServiceWatcher: deploying..." 2>&1

if ! [[ -d "$SERVICE_WATCHER_INSTALL_DIR" ]]; then
  rm -rf "$SERVICE_WATCHER_INSTALL_DIR"
  mkdir -p "$SERVICE_WATCHER_INSTALL_DIR"
fi

if [[ -f $SERVICE_WATCHER_CONFIG ]]; then
  cp $SERVICE_WATCHER_CONFIG /tmp/service_watcher_config.yml
  rm -rf $SERVICE_WATCHER_INSTALL_DIR/*
  mv /tmp/service_watcher_config.yml $SERVICE_WATCHER_CONFIG
else
  rm -rf $SERVICE_WATCHER_INSTALL_DIR/*
fi

# Extract code archive
tar --strip-components=1 -C "$SERVICE_WATCHER_INSTALL_DIR" -xf "files/service_watcher.tar.xz"

# Install requirements
apt-get -qq install -y libyaml-dev python-gi
pip install --quiet -r "$SERVICE_WATCHER_INSTALL_DIR/requirements.txt"
