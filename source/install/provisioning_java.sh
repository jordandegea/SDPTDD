#!/bin/bash

# Fail if any command fail
set -eo pipefail

# This script must be run as root.
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

if ! java -version >/dev/null 2>&1; then
    # Install the default JRE using apt (see debian docs)
    apt-get install -y default-jre
else
    echo "Java: already installed."
fi
