#!/bin/bash

# Load the shared provisioning script
source ./deploy_shared.sh

JAVA_VERSION=$(java -version 2>&1)
if ! [[ "$JAVA_VERSION" =~ 1\.8 ]]; then
    # Install the default JRE using apt (see debian docs)
    apt-get install -y openjdk-8-jdk
else
    echo "Java: already installed."
fi
