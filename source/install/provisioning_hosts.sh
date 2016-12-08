#!/bin/bash

# Fail if any command fail
set -eo pipefail

# Load the shared provisioning script
if [ -f './provisioning_shared.sh' ]; then
  source ./provisioning_shared.sh
else
  source /vagrant/provisioning_shared.sh
fi

# Parse host definitions from the command line
HOST_DEFS=$(printf "# Cluster hostnames config\n")
while getopts ":H:" opt; do
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
        cat /etc/hosts.head /etc/hosts.tail /etc/hosts
        rm -f /etc/hosts.head /etc/hosts/tail
    fi

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
