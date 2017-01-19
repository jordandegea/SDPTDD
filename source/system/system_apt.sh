#!/bin/bash

# Fail if any command fail
set -e

# Load the shared provisioning script
source ./deploy_shared.sh

# Setup local package cache
# Source: https://superuser.com/questions/303621/local-cache-for-apt-packages
if (($ENABLE_VAGRANT)); then
  if [ "$(readlink /var/cache/apt/archives)" != "$RESOURCES_DIRECTORY" ]; then
    rm -rf /var/cache/apt/archives
    ln -s "$RESOURCES_DIRECTORY" /var/cache/apt/archives
  fi
fi

# Just update packages for future provisioning scripts
apt-get -qq update -y
