#!/bin/bash

# Load the shared provisioning script
source ./deploy_shared.sh

if ! hash pip 2>&1 >/dev/null; then
    # Install pip
    apt-get install -y python-pip
else
    echo "Python: python-pip already installed."
fi
