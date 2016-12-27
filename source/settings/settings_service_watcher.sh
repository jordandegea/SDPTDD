#!/bin/bash

# Fail if any command fail
set -e

# Load the shared provisioning script
source ./deploy_shared.sh

# Load ServiceWatcher install parameters
source ./service_watcher_shared.sh

# Read HBase and ZooKeeper quorum from args
while getopts ":vfz:" opt; do
    case "$opt" in
        z)
        ZOOKEEPER_QUORUM="$OPTARG"
        ;;
    esac
done
OPTIND=1

if ! [[ -d "$SERVICE_WATCHER_INSTALL_DIR" ]]; then
  rm -rf "$SERVICE_WATCHER_INSTALL_DIR"
  mkdir -p "$SERVICE_WATCHER_INSTALL_DIR"
fi

echo "ServiceWatcher: configuring..." 2>&1

if (($ENABLE_VAGRANT)); then
  cp files/service_watcher_config_vagrant.yml $SERVICE_WATCHER_CONFIG
else
  cp files/service_watcher_config.yml $SERVICE_WATCHER_CONFIG
fi

# Create the service watcher binary
echo "#!/bin/bash

if [[ \$EUID -ne 0 ]]; then
  echo \"This script must be run as root\" >&2
  exit 1
fi

python '$SERVICE_WATCHER_INSTALL_DIR/service_watcher.py' --config '$SERVICE_WATCHER_CONFIG' \"\$@\"
" >/usr/local/bin/service_watcher
chmod +x /usr/local/bin/service_watcher

# Replace ZooKeeper quorum in config file
sed -i "s/zookeeper_quorum_replace_me/$ZOOKEEPER_QUORUM/" $SERVICE_WATCHER_CONFIG

# Create the ServiceWatcher systemd service
echo "[Unit]
Description=Twitter Weather ServiceWatcher
Requires=network.target
After=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$SERVICE_WATCHER_INSTALL_DIR
ExecStart=/usr/bin/python $SERVICE_WATCHER_INSTALL_DIR/service_watcher.py monitor --config $SERVICE_WATCHER_CONFIG
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
SyslogIdentifier=service_watcher

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/service_watcher.service
rm -f /etc/systemd/system/service-watcher.service

# On Vagrant, create the dummy_service
if (($ENABLE_VAGRANT)); then
  # Install socat
  apt-get -qq install -y socat
  # Create the socat wrapper script
  WRAPPER=/usr/local/bin/dummy_service
  echo "#!/bin/bash
if [[ \$1 == 'multi' ]]; then
  /usr/bin/socat -v TCP4-LISTEN:\$((2001 + \$2 * 100 + (RANDOM % 100))),fork EXEC:cat
elif [[ \$1 == 'shared' ]]; then
  /usr/bin/socat -v TCP4-LISTEN:2001,fork EXEC:cat
elif [[ \$1 == 'global' ]]; then
  /usr/bin/socat -v TCP4-LISTEN:2000,fork EXEC:cat
fi

EXIT_CODE=\$?
if [[ \$EXIT_CODE -eq 143 ]]; then
  exit 0
else
  exit \$EXIT_CODE
fi
"> $WRAPPER
  chmod +x $WRAPPER

  echo "[Unit]
Description=ServiceWatcher dummy (global) unit for testing
Requires=network.target
After=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=$WRAPPER global
Restart=on-failure
SyslogIdentifier=dummy_global

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/dummy_global.service

  echo "[Unit]
Description=ServiceWatcher dummy (shared) unit for testing
Requires=network.target
After=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=$WRAPPER shared
Restart=on-failure
SyslogIdentifier=dummy_shared

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/dummy_shared.service

  echo "[Unit]
Description=ServiceWatcher dummy (instance %i) unit for testing
Requires=network.target
After=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=$WRAPPER multi %i
Restart=on-failure
SyslogIdentifier=dummy_multi@%i

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/dummy_multi@.service
fi

# Reload unit files
systemctl daemon-reload
