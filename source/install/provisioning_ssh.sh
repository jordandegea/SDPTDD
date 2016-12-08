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
    echo "Not yet implemented" >&2
fi

# NODES=$1
# 
# pushd .
# cd ~/.ssh
# rm -f ~/.ssh/id_rsa*
# ssh-keygen -q -t rsa -P "" -f /home/vagrant/.ssh/id_rsa
# eval `ssh-agent -s`
# eval "$(ssh-agent)"
# ssh-add -L
# ssh-add
# ssh-add -L
# 
# echo "ssh-copy-id start"
# for i in $(seq 1 $NODES);do
	# sshpass -pvagrant ssh-copy-id -o StrictHostKeyChecking=no -i /home/vagrant/.ssh/id_rsa.pub vagrant@10.20.1.1$(printf %02d $i)
# done
# echo "ssh-copy-id end"
# 
# popd
# 