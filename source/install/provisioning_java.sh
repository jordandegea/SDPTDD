#!/bin/bash

# This script must be run as root.
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

JAVA_VERSION=$(java -version 2>&1)
if ! [[ "$JAVA_VERSION" =~ 1\.8 ]]; then
    # Install the default JRE using apt (see debian docs)
    apt install -y openjdk-8-jdk
else
    echo "Java: already installed."
fi
