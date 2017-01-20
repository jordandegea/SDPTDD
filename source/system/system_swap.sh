#!/bin/bash

# Fail if any command fail
set -e

if ! [ -f /var/swap ]; then
  touch /var/swap
  chmod 0600 /var/swap
  dd if=/dev/zero of=/var/swap bs=1024k count=2000
  mkswap /var/swap
fi

if ! swapon | grep /var/swap >/dev/null ; then
  swapon /var/swap
fi
