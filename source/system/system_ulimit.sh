#!/bin/bash

# Load the shared provisioning script
source ./deploy_shared.sh

echo "flink soft nofile 100000
flink hard nofile 100000
" > /etc/security/limits.conf
