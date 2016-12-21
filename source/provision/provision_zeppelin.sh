#!/bin/bash

# Fail if any command fail
set -eo pipefail

# Load the shared provisioning script
source ./deploy_shared.sh

ZEPPELIN_VERSION=0.6.2
ZEPPELIN_NAME=zeppelin-$ZEPPELIN_VERSION
ZEPPELIN_FILENAME=$ZEPPELIN_NAME-bin-all.tgz
ZEPPELIN_INSTALL_DIR="/usr/local/zeppelin"
ZEPPELIN_LOG_DIR="/usr/local/zeppelin/logs"


SERVICE_FILE="/etc/systemd/system/zeppelin.service"
START_SCRIPT="$ZEPPELIN_INSTALL_DIR/bin/zeppelin-daemon.sh start"
STOP_SCRIPT="$ZEPPELIN_INSTALL_DIR/bin/zeppelin-daemon.sh stop"

# Create the hbase user if necessary
if ! id -u zeppelin >/dev/null 2>&1; then
	echo "Zeppelin: creating user..." 1>&2
	useradd -m -s /bin/bash zeppelin
	sudo passwd -d zeppelin
else
	echo "Zeppelin: user already created." 1>&2
fi

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
	export HBASE_HOME=/usr/local/hbase
	export HBASE_RUBY_SOURCES=/usr/local/hbase/lib/ruby/
	" >> zeppelin/conf/zeppelin-env.sh


  echo "Zeppelin: successfully installed!" 1>&2


else
  echo "Zeppelin: already installed." 1>&2
fi

# Create the hbase systemd service
if (($FORCE_INSTALL)) || ! [ -f $SERVICE_FILE ]; then
	echo "[Unit]
Description=Apache Zeppelin
Requires=network.target
After=network.target

[Service]
Type=forking
User=zeppelin
Group=zeppelin
Environment=LOG_DIR=$ZEPPELIN_LOG_DIR
Environment=HBASE_LOG_DIR=$ZEPPELIN_INSTALL_DIR
ExecStart=$START_SCRIPT
ExecStop=$STOP_SCRIPT
Restart=on-failure
SyslogIdentifier=zeppelin

[Install]
WantedBy=multi-user.target" > $SERVICE_FILE
fi

# Reload unit files
# systemctl daemon-reload #temp removed

/usr/local/zeppelin/bin/zeppelin-daemon.sh start # temporary (bypass service)