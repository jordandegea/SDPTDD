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

# Deploy jar
cp files/ServiceWatcher.jar $SERVICE_WATCHER_INSTALL_DIR
