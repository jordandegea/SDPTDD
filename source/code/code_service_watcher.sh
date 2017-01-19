#!/bin/bash

# Fail if any command fail
set -e

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

# Fix permissions
chown root:root -R "$SERVICE_WATCHER_INSTALL_DIR"
find "$SERVICE_WATCHER_INSTALL_DIR" -type f -print0 | xargs -0 chmod 0644
find "$SERVICE_WATCHER_INSTALL_DIR" -type d -print0 | xargs -0 chmod 0755
chmod 0755 "$SERVICE_WATCHER_INSTALL_DIR/service_watcher.py"

# Install requirements
export LC_ALL=C
apt-get -qq install -y libyaml-dev python-gi
pip install --quiet -r "$SERVICE_WATCHER_INSTALL_DIR/requirements.txt"
