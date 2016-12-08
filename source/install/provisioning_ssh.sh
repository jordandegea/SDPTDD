#!/bin/bash

# Fail if any command fail
set -eo pipefail

# Load the shared provisioning script
if [ -f './provisioning_shared.sh' ]; then
  source ./provisioning_shared.sh
else
  source /vagrant/provisioning_shared.sh
fi

if (($ENABLE_VAGRANT)); then
    # Ensure directory is created
    if ! [ -d ~vagrant/.ssh ]; then
        mkdir -p ~vagrant/.ssh
    fi

    # Base config
    printf "Host *\n\tStrictHostKeyChecking no\n\n" >~vagrant/.ssh/config

    # We have the "machines" directory copied inside the current directory
    for MACHINE_DIR in $(ls machines); do
        # Get the machine name from the directory
        MACHINE_NAME=$(basename $MACHINE_DIR)
        echo "SSH: Configuring for $MACHINE_NAME"

        # Copy the private key
        KEYFILE=~vagrant/.ssh/$MACHINE_NAME
        cp machines/$MACHINE_DIR/virtualbox/private_key $KEYFILE
        chmod 0600 $KEYFILE

        # Generate the config
        printf "Host %s\n\tIdentityFile %s\n\n" $MACHINE_NAME "~/.ssh/$MACHINE_NAME" >>~vagrant/.ssh/config
    done

    # Ensure ownership
    chown vagrant:vagrant -R ~vagrant/.ssh
else
    # Ensure directory is created
    if ! [ -d ~xnet/.ssh ]; then
        mkdir -p ~xnet/.ssh
    fi

    # Base config
    printf "Host *\n\tStrictHostKeyChecking no\n\n" >~xnet/.ssh/config

    # Copy the key to .ssh
    cp xnet xnet.pub ~xnet/.ssh/
    chmod 0600 ~xnet/.ssh/xnet

    while getopts ":H:" opt; do
        case "$opt" in
            H)
            while IFS='@' read -ra ADDR; do
                SRV_HOSTNAME="${ADDR[0]}"
                SRV_ADDRESS="${ADDR[1]}"

                # Generate the config for this host
                printf "Host %s\n\tIdentityFile ~/.ssh/xnet\n\n" $SRV_HOSTNAME >>~xnet/.ssh/config
            done <<< "$OPTARG"
            ;;
        esac
    done

    # Ensure right ownership
    chown xnet:xnet -R ~xnet/.ssh
fi
