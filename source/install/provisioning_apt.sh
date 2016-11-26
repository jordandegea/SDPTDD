#!/bin/bash

# Fail if any command fail
set -eo pipefail

# This script must be run as root.
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

# Just update packages for future provisioning scripts
apt-get update
