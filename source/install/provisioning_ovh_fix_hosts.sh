#!/bin/bash

# Fail if any command fail
set -eo pipefail

# Load the shared provisioning script
if [ -f './provisioning_shared.sh' ]; then
  source ./provisioning_shared.sh
else
  source /vagrant/provisioning_shared.sh
fi

# Fix the hostfile to ensure it's not missing the hostname as 127.0.0.1
if ! grep "127.0.0.1.*$(hostname)" /etc/hosts 2>/dev/null ; then
    sed -i "s/^127.0.0.1\\s*localhost$/127.0.0.1\tlocalhost $(hostname)/" /etc/hosts
fi
