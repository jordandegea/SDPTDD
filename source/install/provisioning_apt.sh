#!/bin/bash

# Fail if any command fail
set -eo pipefail

# This script must be run as root.
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

# Detect the environment
ENABLE_VAGRANT=0
while getopts ":vf" opt; do
  case $opt in
    v)
      echo "Running in vagrant mode." 1>&2
      ENABLE_VAGRANT=1
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done

# Setup local package cache
# Source: https://superuser.com/questions/303621/local-cache-for-apt-packages
if (($ENABLE_VAGRANT)); then
  if [ "$(readlink /var/cache/apt/archives)" != "/vagrant/resources" ]; then
    rm -rf /var/cache/apt/archives
    ln -s /vagrant/resources /var/cache/apt/archives
  fi
fi

# Just update packages for future provisioning scripts
apt-get update
