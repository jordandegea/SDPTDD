#!/bin/bash

# Fail if any command fail
set -eo pipefail

# Load the shared provisioning script
if [ -f './provisioning_shared.sh' ]; then
	source ./provisioning_shared.sh
else
	source /vagrant/provisioning_shared.sh
fi

filename="flink-1.1.3"
bindir="/opt/$filename/bin"

function downloadFlink {
	filename="$filename.tgz"
	echo "Flink: downloading..."
	get_file "http://apache.mirrors.ovh.net/ftp.apache.org/dist/flink/flink-1.1.3/flink-1.1.3-bin-hadoop1-scala_2.10.tgz" $filename
}

echo "Setting up Flink"
downloadFlink
tar -oxzf $filename -C /opt
$bindir/start-local.sh
echo "Flink installed"
