#!/bin/bash

# Fail if any command fail
set -e

# Load the shared provisioning script
source ./deploy_shared.sh

# Load Spark install parameters
source ./spark_shared.sh

echo "log4j.rootLogger = INFO, stdout
log4j.appender.stdout = org.apache.log4j.ConsoleAppender
log4j.appender.stdout.layout = org.apache.log4j.PatternLayout
log4j.appender.stdout.layout.ConversionPattern=%5p [%d] ({%t} %F[%M]:%L) - %m%n
" > $SPARK_INSTALL_DIR/conf/log4j.properties

sed -i 's# >> "$log"##' $SPARK_INSTALL_DIR/sbin/spark-daemon.sh

# Create the Spark systemd service
echo "[Unit]
Description=Apache Spark %i
Requires=network.target
After=network.target

[Service]
Type=forking
User=zeppelin
Group=zeppelin
Restart=on-failure
SyslogIdentifier=spark@%i

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/spark@.service

# Create master and slave overrides
mkdir -p /etc/systemd/system/spark@master.service.d
echo "[Service]
ExecStart=$SPARK_INSTALL_DIR/sbin/start-master.sh -p 7077 --webui-port 8082
ExecStop=$SPARK_INSTALL_DIR/sbin/stop-master.sh
" >/etc/systemd/system/spark@master.service.d/override.conf

mkdir -p /etc/systemd/system/spark@slave.service.d
echo "[Service]
ExecStart=/bin/bash -c '$SPARK_INSTALL_DIR/sbin/start-slave.sh \$(cat $SPARK_INSTALL_DIR/master) --webui-port 8083'
ExecStop=$SPARK_INSTALL_DIR/sbin/stop-slave.sh
" >/etc/systemd/system/spark@slave.service.d/override.conf

# Reload unit files
systemctl daemon-reload 