#!/bin/bash

# Fail if any command fail
set -eo pipefail

# Load the shared provisioning script
if [ -f './provisioning_shared.sh' ]; then
  source ./provisioning_shared.sh
else
  source /vagrant/provisioning_shared.sh
fi

JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64

HBASE_VERSION="1.0.3"
HBASE_LOG_DIR="/var/log/hbase"
HBASE_TGZ="hbase-$HBASE_VERSION-bin.tar.gz"
HBASE_URL="http://wwwftp.ciril.fr/pub/apache/hbase/hbase-$HBASE_VERSION/$HBASE_TGZ"
HBASE_HOME="/usr/lib/hbase"

SERVICE_FILE="/etc/systemd/system/hbase.service"
START_SCRIPT="/usr/lib/hbase/start-hbase.sh"
STOP_SCRIPT="/usr/lib/hbase/stop-hbase.sh"

# Download HBase
if (($FORCE_INSTALL)) || ! [ -d $HBASE_HOME ]
then
    echo "HBase: Download"
    get_file $HBASE_URL $HBASE_TGZ
    tar -oxzf $HBASE_TGZ -C .
    rm $HBASE_TGZ
    rm -rf $HBASE_HOME
    mv hbase* $HBASE_HOME
fi


# Configure HBase
echo "HBase: Configuration"
cd $HBASE_HOME/conf

echo "
export JAVA_HOME=$JAVA_HOME
" >> hbase-env.sh

echo "
<configuration>
  <property>
    <name>hbase.rootdir</name>
    <value>file:///hbase</value>
  </property>
  <property>
    <name>hbase.cluster.distributed</name>
    <value>true</value>
  </property>
</configuration>
" > hbase-site.xml

# Create the hbase user if necessary
if ! id -u hbase >/dev/null 2>&1; then
  echo "HBase: creating user..." 1>&2
  useradd -m -s /bin/bash hbase
else
  echo "HBase: user already created." 1>&2
fi

rm -rf ~/hbase/.ssh
if (($ENABLE_VAGRANT)); then
  cp -r ~vagrant/.ssh ~hbase/.ssh
else
  cp -r ~xnet/.ssh ~hbase/.ssh
fi

echo "[Unit]
Description=Apache HBase
Requires=network.target
After=network.target

[Service]
Type=forking
User=hbase
Group=hbase
Environment=LOG_DIR=$HBASE_LOG_DIR
ExecStart=$START_SCRIPT
ExecStop=$STOP_SCRIPT
Restart=on-failure
SyslogIdentifier=hbase

[Install]
WantedBy=multi-user.target" > $SERVICE_FILE