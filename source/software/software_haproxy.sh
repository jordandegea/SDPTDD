#!/bin/bash

# Fail if any command fail
set -e

# Load the shared provisioning script
source ./deploy_shared.sh

if ! hash haproxy 2>/dev/null ; then
  if (($ENABLE_VAGRANT)); then
    echo deb http://httpredir.debian.org/debian jessie-backports main | \
        sed 's/\(.*\)-sloppy \(.*\)/&@\1 \2/' | tr @ '\n' | \
        tee /etc/apt/sources.list.d/backports.list
    apt-get install -y -qq haproxy -t jessie-backports
  else
    apt-get install -y -qq software-properties-common
    add-apt-repository -y ppa:vbernat/haproxy-1.7
    apt-get install -y -qq haproxy
  fi
fi
