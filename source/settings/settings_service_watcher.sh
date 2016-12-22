#!/bin/bash

# Fail if any command fail
set -eo pipefail

# Load the shared provisioning script
source ./deploy_shared.sh

# Load ServiceWatcher install parameters
source ./service_watcher_shared.sh

echo "ServiceWatcher: configuring..." 2>&1

if ! [[ -d "$SERVICE_WATCHER_INSTALL_DIR" ]]; then
  rm -rf "$SERVICE_WATCHER_INSTALL_DIR"
  mkdir -p "$SERVICE_WATCHER_INSTALL_DIR"
fi

# Create the hbase systemd service
echo "[Unit]
Description=Twitter Weather ServiceWatcher
Requires=network.target zookeeper.service
After=network.target zookeeper.service

[Service]
Type=simple
User=zookeeper
Group=zookeeper
Environment=LOG_DIR=$ZOOKEEPER_LOG_DIR
ExecStart=/usr/bin/java -jar $SERVICE_WATCHER_INSTALL_DIR/ServiceWatcher.jar localhost:2181
SyslogIdentifier=service-watcher

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/service-watcher.service

# Reload unit files
systemctl daemon-reload
