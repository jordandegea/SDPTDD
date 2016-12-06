#!/bin/bash

# Load the shared provisioning script
if [ -f './provisioning_shared.sh' ]; then
  source ./provisioning_shared.sh
else
  source /vagrant/provisioning_shared.sh
fi

JAVA_VERSION=$(java -version 2>&1)
if ! [[ "$JAVA_VERSION" =~ 1\.8 ]]; then
    # Install the default JRE using apt (see debian docs)
    apt install -y openjdk-8-jdk
else
    echo "Java: already installed."
fi
