#!/bin/bash

# Fail if any command fail
set -e

# Load the shared provisioning script
source ./deploy_shared.sh

# Load Zeppelin install parameters
source ./zeppelin_shared.sh

# Create the hbase user if necessary
if ! id -u zeppelin >/dev/null 2>&1; then
  echo "Zeppelin: creating user..." 1>&2
  useradd -m -s /bin/bash zeppelin
  sudo passwd -d zeppelin
else
  echo "Zeppelin: user already created." 1>&2
fi

if ! [ -d $ZEPPELIN_LOG_DIR ]; then
  mkdir -p $ZEPPELIN_LOG_DIR
  chown zeppelin:zeppelin -R $ZEPPELIN_LOG_DIR
fi

chown zeppelin:zeppelin -R $ZEPPELIN_INSTALL_DIR

# Create the zeppelin systemd service
echo "[Unit]
Description=Apache Zeppelin
Requires=network.target
After=network.target

[Service]
Type=forking
User=zeppelin
Group=zeppelin
ExecStart=$START_SCRIPT
ExecStop=$STOP_SCRIPT
Restart=on-failure
SyslogIdentifier=zeppelin

[Install]
WantedBy=multi-user.target" > $SERVICE_FILE

# Reload unit files
systemctl daemon-reload 