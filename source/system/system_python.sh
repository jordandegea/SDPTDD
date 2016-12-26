#!/bin/bash

# Load the shared provisioning script
source ./deploy_shared.sh

# Install pip and python-dev
echo "Python: installing required tools..." 2>&1
apt-get -qq install -y python-pip python-dev
