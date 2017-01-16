#!/bin/bash

# Fail if any command fail
set -e

# Load the shared provisioning script
source ./deploy_shared.sh

# ZK parameters
source ./kafka_shared.sh

# BK parameters
source ./bookkeeper_shared.sh

while getopts ":vfz:" opt; do
  case "$opt" in
    z)
      ZOOKEEPER_QUORUM="$OPTARG"
      ;;
  esac
done

# Update the BookKeeper config
echo "#!/bin/sh
## Bookie settings

# Port that bookie server listen on
bookiePort=3181

# Directory Bookkeeper outputs its write ahead log
journalDirectory=/home/zookeeper/bk-txn

# Directory Bookkeeper outputs ledger snapshots
ledgerDirectories=/home/zookeeper/bk-data

## zookeeper client settings

zkServers=$ZOOKEEPER_QUORUM
zkTimeout=10000

# Use hostname as ID
useHostNameAsBookieID=true
" > $BOOKKEEPER_HOME/conf/bk_server.conf

# Create the BookKeeper systemd service
echo "[Unit]
Description=Apache BookKeeper bookie
Requires=network.target
After=network.target

[Service]
Type=forking
User=zookeeper
Group=zookeeper
Environment=BOOKIE_LOG_DIR=$ZOOKEEPER_LOG_DIR
ExecStart=$BOOKKEEPER_HOME/bin/bookkeeper-daemon.sh start bookie 
ExecStop=-$BOOKKEEPER_HOME/bin/bookkeeper-daemon.sh stop bookie
Restart=on-failure
SyslogIdentifier=bookkeeper

[Install]
WantedBy=multi-user.target" > $BOOKKEEPER_SERVICE_FILE

# Reload unit files
systemctl daemon-reload
