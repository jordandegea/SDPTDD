#!/bin/bash

get_loop_device () {
  losetup -j $DEVICE_FILE | cut -d: -f1
}

resource_status () {
  drbdadm status $RESOURCE_NAME 2>&1
}

resource_up () {
  resource_status >/dev/null
}

resource_primary () {
  [ $(drbdadm role $RESOURCE_NAME) == "Primary" ]
}

print_usage () {
  echo "Usage: ${BASH_SOURCE} [-n] [-h] initlo|initsync|initmd|mkconfig|up|down|start|stop" >&2
}

initlo_device () {
  LOOP_DEV=$(get_loop_device)
  if [ -z "$LOOP_DEV" ]; then
    losetup -P -f $DEVICE_FILE
    LOOP_DEV=$(get_loop_device)
  fi
}

do_mkconfig () {
  # Create resource file
    sed "s#replace_me_device_loop#${LOOP_DEV}#" ${RESOURCE_FILE}.tpl > $RESOURCE_FILE
    echo "Wrote $RESOURCE_FILE"
}

while getopts ":nhM" opt; do
  case "$opt" in
    n)
      NO_ENV=yes
    ;;
    M)
      NO_MOUNT=yes
    ;;
    h)
      print_usage
      exit 0
    ;;
  esac
done

ACTION="${@:$OPTIND:1}"

if [ -z "$NO_ENV" ]; then
  ENV_FILE="$(dirname "$BASH_SOURCE")/drbd_service_env.sh"
  if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
  fi
fi

if [ -z "$RESOURCE_NAME" ]; then
  echo "Missing \$RESOURCE_NAME in environment" >&2
  exit 2
fi

if [ -z "$DEVICE_FILE" ]; then
  echo "Missing \$DEVICE_FILE in environment" >&2
  exit 2
fi

if [ -z "$RESOURCE_FILE" ]; then
  echo "Missing \$RESOURCE_FILE in environment" >&2
  exit 2
fi

if [ -z "$DEVICE_DEV" ]; then
  echo "Missing \$DEVICE_DEV in environment" >&2
  exit 2
fi

case "$ACTION" in
  initlo)
    initlo_device

    if [ -z "$(get_loop_device)" ]; then
      echo "Could not bring up loop device"
      exit 3
    else
      echo "Loop device brought up as $LOOP_DEV"
      exit 0
    fi
    ;;
  initsync)
    if ! resource_up; then
      echo "Resource is not up!" >&2
      exit 3
    fi

    echo "Waiting for cluster connect"
    while resource_status | grep -e Connecting -e Unconnected >/dev/null ; do
      sleep 5
    done

    STATUS=$(resource_status)
    if grep Inconsistent >/dev/null <<< "$STATUS" ; then
      echo "Performing initial sync"
      drbdadm primary --force $RESOURCE_NAME

      echo "Initial sync in progress, please wait..."
      while resource_status | grep Inconsistent >/dev/null ; do
        sleep 5
      done

      echo "Initial sync complete!"
      resource_status
      exit 0
    else
      echo "Resources already in sync!"
      echo "$STATUS"
      exit 0
    fi
    ;;
  initmd)
    echo "Creating metadata..."
    initlo_device
    do_mkconfig
    printf "no\n" | drbdadm create-md $RESOURCE_NAME
    exit 0
    ;;
  mkconfig)
    do_mkconfig
    ;;
  up)
    # Ensure drbd1 is up
    if ! resource_up; then
      echo "Bringing up $RESOURCE_NAME"

      # Mount loop FS
      initlo_device
      do_mkconfig

      # Start drbd
      drbdadm up $RESOURCE_NAME
    fi
    ;;
  down)
    # Ensure drbd1 is down
    if resource_up; then
      echo "Brinding down $RESOURCE_NAME"
      drbdadm down $RESOURCE_NAME
    fi

    # Down all loopback files
    for I in $(get_loop_device); do
      losetup -d $I
    done
    ;;
  start)
    if ! resource_up; then
      echo "Resource not up for start"
      exit 3
    fi

    # Wait for primary
    while ! resource_primary ; do
      sleep 10
      drbdadm primary $RESOURCE_NAME
    done

    if [ -z "$NO_MOUNT" ]; then
      # Mount filesystem
      mkdir -p /mnt/shared
      if ! mount -t ext4 $DEVICE_DEV /mnt/shared ; then
        echo "Failed to mount device"
        exit 3
      fi
    else
      echo "Not mounting device"
      exit 0
    fi
    ;;
  stop)
    if [ -z "$NO_MOUNT" ]; then
      if ! umount /mnt/shared ; then
        echo "Failed to unmount device"
        exit 2
      fi
    else
      echo "Not unmounting device"
    fi

    # Go secondary
    drbdadm secondary $RESOURCE_NAME
    while resource_primary ; do
      sleep 10
      drbdadm secondary $RESOURCE_NAME
    done

    echo "$RESOURCE_NAME is now secondary"
    exit 0
    ;;
  *)
    print_usage
    exit 2
    ;;
esac
