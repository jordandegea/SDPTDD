#!/bin/bash

# Fail if any command fail
set -eo pipefail

# Load the shared provisioning script
if [ -f './provisioning_shared.sh' ]; then
  source ./provisioning_shared.sh
else
  source /vagrant/provisioning_shared.sh
fi

ZEPPELIN_VERSION=0.6.2
ZEPPELIN_NAME=zeppelin-$ZEPPELIN_VERSION
ZEPPELIN_FILENAME=$ZEPPELIN_NAME-bin-all.tgz
ZEPPELIN_INSTALL_DIR=/usr/local/zeppelin

if(($FORCE_INSTALL)) || ! [ -d $ZEPPELIN_INSTALL_DIR ]; then
	# Download Zeppelin
	echo "Zeppelin: downloading..."

	get_file "http://apache.mindstudios.com/zeppelin/$ZEPPELIN_NAME/$ZEPPELIN_FILENAME" $ZEPPELIN_FILENAME

	#Install in the right location
	echo "Zeppelin: Installing..."

	mv $ZEPPELIN_FILENAME /usr/local
	cd /usr/local/
	tar xf $ZEPPELIN_FILENAME
	rm $ZEPPELIN_FILENAME
	rm -rf $ZEPPELIN_INSTALL_DIR
	mv $ZEPPELIN_NAME-bin-all $ZEPPELIN_INSTALL_DIR


	echo "
	export HBASE_HOME=/usr/lib/hbase
	" >> zeppelin/conf/zeppelin-env.sh


  echo "Zeppelin: successfully installed!" 1>&2


else
  echo "Zeppelin: already installed." 1>&2
fi
