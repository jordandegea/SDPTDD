#!/bin/bash

# Fail if any command fail
set -e

# Load the shared provisioning script
source ./deploy_shared.sh

# Parse host definitions from the command line
HOST_DEFS=$(printf "# Cluster hostnames config\n")
while getopts ":vfH:" opt; do
  case "$opt" in
    H)
      while IFS='@' read -ra ADDR; do
        HOST_DEFS=$(printf "%s\n%s\t%s" "$HOST_DEFS" "${ADDR[1]}" "${ADDR[0]}")
      done <<< "$OPTARG"
      ;;
  esac
done

# Create a working hostfile
if (($ENABLE_VAGRANT)); then
    # Remove lines containing hostname
    sed -i "s/127.0.0.1\t$(hostname)\t$(hostname)//" /etc/hosts

    # Ensure localhost is still defined
    if ! grep "127.0.0.1.*localhost" /etc/hosts 2>/dev/null ; then
        printf "127.0.0.1\tlocalhost" >/etc/hosts.head
        mv /etc/hosts /etc/hosts.tail
        cat /etc/hosts.head /etc/hosts.tail >/etc/hosts
        rm -f /etc/hosts.head /etc/hosts/tail
    fi

    # Clear old namenods definitions
    sed -i 's/^.*namenode//' /etc/hosts

    # Hostnames are already configured by Vagrant hostmanager
else
    printf "127.0.0.1\tlocalhost

# The following lines are desirable for IPv6 capable hosts
::1 ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts

%s\n" "$HOST_DEFS" >/etc/hosts
fi

cp /etc/hosts /etc/hosts.tpl
echo "
nn_ip currentnamenode
" >> /etc/hosts.tpl
