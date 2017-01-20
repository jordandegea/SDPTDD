#!/bin/bash

# Fail if any command fail
set -e

# Load shared params
source ./deploy_shared.sh

# Swap parameters
FILE_SIZE=2G
SWAPFILE=/swap

# Create the swap file on /
if ! [ -f $SWAPFILE ]; then
  fallocate -l $FILE_SIZE $SWAPFILE
  chmod 0600 $SWAPFILE
  mkswap $SWAPFILE
fi

# Enable the swap file
if ! swapon | grep $SWAPFILE >/dev/null ; then
  swapon $SWAPFILE
fi

# Update /etc/fstab
sed -i "s#.*${SWAPFILE}.*\n##" /etc/fstab
printf "%s\tnone\tswap\tsw\t0\t0\n" "$SWAPFILE" >> /etc/fstab
