#!/bin/bash

# Fail if any command fail
set -ex

# Load the shared provisioning script
source ./deploy_shared.sh

# Disable safety
set +eo pipefail

export DEVICE_DEV=/dev/drbd1
export RESOURCE_NAME=r0
export DEVICE_FILE=/root/drbd.img
export RESOURCE_FILE=/etc/drbd.d/${RESOURCE_NAME}.res

# Copy the service tool script
chown root:root files/drbd_service.sh
cp files/drbd_service.sh /usr/local/bin
chmod +x /usr/local/bin/drbd_service.sh

# Build the env file
echo "RESOURCE_NAME=$RESOURCE_NAME
DEVICE_FILE=$DEVICE_FILE
RESOURCE_FILE=$RESOURCE_FILE
DEVICE_DEV=$DEVICE_DEV
" >/usr/local/bin/drbd_service_env.sh

# Alias
DRBDS="/usr/local/bin/drbd_service.sh -n -M"

# Configure
echo "resource ${RESOURCE_NAME} {
  device    ${DEVICE_DEV};
  disk      replace_me_device_loop;
  meta-disk internal;
" > ${RESOURCE_FILE}.tpl

# Parse host definitions from the command line
HOST_INDEX=0
HOSTS=""
ADDRS=""
FIRST_HOST=""
while getopts ":vfH:" opt; do
  case "$opt" in
    H)
      while IFS='@' read -ra ADDR; do
        HOSTS="$HOSTS ${ADDR[0]}"
        ADDRS="$ADDRS ${ADDR[1]}"
        if [ "$HOST_INDEX" == 0 ]; then
          FIRST_HOST="${ADDR[0]}"
        fi
      done <<< "$OPTARG"
      HOST_INDEX=$((HOST_INDEX+1))
      ;;
  esac
done
HOST_INDEX=$((HOST_INDEX-1))

# Convert to Bash arrays
HOSTS_SPACE="$HOSTS"
read -ra HOSTS <<< "$HOSTS"
read -ra ADDRS <<< "$ADDRS"

# Specify hosts
for I in $(seq 0 $HOST_INDEX); do
  echo "  on ${HOSTS[$I]} { address ${ADDRS[$I]}:$((7000+I)); node-id $I; }
" >> ${RESOURCE_FILE}.tpl
done

# Create the connection mesh
echo "  connection-mesh {
    hosts $HOSTS_SPACE;
    net {
        use-rle no;
    }
  }
}
" >> ${RESOURCE_FILE}.tpl

if drbdadm status $RESOURCE_NAME | grep Primary >/dev/null ; then
  echo "DRBD: Not processing with DRBD config, already one primary running..."
else
  # Disable resource
  $DRBDS down

  # Create block device
  if (($FORCE_INSTALL)) || ! [ -f "$DEVICE_FILE" ]; then
    echo "DRBD: Creating block device..."

    # Delete previous file
    rm -f $DEVICE_FILE

    # Allocate file
    fallocate -l 2G $DEVICE_FILE
  fi

  # Initialize metadata, will bring up lodevice
  $DRBDS initmd

  # Initial device sync
  $DRBDS up

  if [ "$(hostname)" == "$FIRST_HOST" ]; then
    $DRBDS initsync
    $DRBDS start

    if ! file -s $DEVICE_DEV | grep 'ext4 filesystem' >/dev/null ; then
      echo "DRBD: Formatting ext4 partition..."
      mkfs.ext4 $DEVICE_DEV
    fi

    $DRBDS stop
  fi
fi

echo "[Unit]
Description=DRBD Primary service $DEVICE_DEV
Requires=network.target drbd-base.service
After=network.target drbd-base.service

[Service]
User=root
Group=root
Type=oneshot
ExecStart=/usr/local/bin/drbd_service.sh start
ExecStop=/usr/local/bin/drbd_service.sh stop
SyslogIdentifier=drbd-primary

[Install]
WantedBy=multi-user.target
" > /etc/systemd/system/drbd-primary.service

echo "[Unit]
Description=DRBD Base service $DEVICE_DEV
Requires=network.target
After=network.target

[Service]
User=root
Group=root
Type=oneshot
ExecStart=/usr/local/bin/drbd_service.sh up
SyslogIdentifier=drbd-base

[Install]
WantedBy=multi-user.target
" > /etc/systemd/system/drbd-base.service

systemctl daemon-reload
systemctl enable drbd-base.service
