#!/bin/bash

# Fail if any command fail
set -eo pipefail

# Load the shared provisioning script
source ./deploy_shared.sh

# Load flink setup parameters
source ./flink_shared.sh

filename="flink-1.1.3"
bindir="${FLINK_INSTALL_DIR}/bin"

function downloadFlink {
  filename="$filename.tgz"
  echo "Flink: downloading..."
  get_file "http://apache.mirrors.ovh.net/ftp.apache.org/dist/flink/flink-1.1.3/flink-1.1.3-bin-hadoop1-scala_2.10.tgz" $filename
}

echo "Setting up Flink"

downloadFlink
tar -xzf $filename -C /usr/local
rm -rf $FLINK_INSTALL_DIR
mv /usr/local/$(basename "$filename" .tgz) ${FLINK_INSTALL_DIR}
