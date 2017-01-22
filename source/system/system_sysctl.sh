#!/bin/bash

# Load the shared provisioning script
source ./deploy_shared.sh

# File limits and swappiness
echo "vm.swappiness=30
fs.file-max = 500000
" > /etc/sysctl.conf

# Disable IPv6
echo "net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
" >> /etc/sysctl.conf
sysctl -p

if ! (($ENABLE_VAGRANT)); then
  ip a del $(ifconfig ens3 | awk '/inet6/ {print $3}') dev ens3
else
  ip a del $(ifconfig eth0 | awk '/inet6/ {print $3}') dev eth0
  ip a del $(ifconfig eth1 | awk '/inet6/ {print $3}') dev eth1
fi

exit 0