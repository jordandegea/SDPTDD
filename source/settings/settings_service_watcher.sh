#!/bin/bash

# Fail if any command fail
set -eo pipefail

# Load the shared provisioning script
source ./deploy_shared.sh

# Load ServiceWatcher install parameters
source ./service_watcher_shared.sh

if ! [[ -d "$SERVICE_WATCHER_INSTALL_DIR" ]]; then
  rm -rf "$SERVICE_WATCHER_INSTALL_DIR"
  mkdir -p "$SERVICE_WATCHER_INSTALL_DIR"
fi

echo "ServiceWatcher: configuring..." 2>&1

if (($ENABLE_VAGRANT)); then
  cp files/service_watcher_config_vagrant.yml $SERVICE_WATCHER_INSTALL_DIR/config.yml
else
  cp files/service_watcher_config.yml $SERVICE_WATCHER_INSTALL_DIR/config.yml
fi

# TODO: Use ZooKeeper quorum from -H
ZOOKEEPER_QUORUM='localhost:2181'

# Replace ZooKeeper quorum in config file
sed -i "s/zookeeper_quorum_replace_me/$ZOOKEEPER_QUORUM/" $SERVICE_WATCHER_INSTALL_DIR/config.yml

# Create the ServiceWatcher systemd service
echo "[Unit]
Description=Twitter Weather ServiceWatcher
Requires=network.target zookeeper.service
After=network.target zookeeper.service

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$SERVICE_WATCHER_INSTALL_DIR
ExecStart=/usr/bin/python $SERVICE_WATCHER_INSTALL_DIR/service_watcher.py monitor --config $SERVICE_WATCHER_INSTALL_DIR/config.yml
Restart=on-failure
SyslogIdentifier=service_watcher

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/service_watcher.service
rm -f /etc/systemd/system/service-watcher.service

# Reload unit files
systemctl daemon-reload
