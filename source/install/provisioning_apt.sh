#!/bin/bash

# Fail if any command fail
set -eo pipefail

# Load the shared provisioning script
source /vagrant/provisioning_shared.sh

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
