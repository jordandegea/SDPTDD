#!/bin/bash

# Fail if any command fail
set -e

# Load the shared provisioning script
source ./deploy_shared.sh

# Load Zeppelin install parameters
source ./zeppelin_shared.sh

# Create the hbase user if necessary
if ! id -u zeppelin >/dev/null 2>&1; then
  echo "Zeppelin: creating user..." 1>&2
  useradd -m -s /bin/bash zeppelin
  sudo passwd -d zeppelin
else
  echo "Zeppelin: user already created." 1>&2
fi

if ! [ -d $ZEPPELIN_LOG_DIR ]; then
  mkdir -p $ZEPPELIN_LOG_DIR
  chown zeppelin:zeppelin -R $ZEPPELIN_LOG_DIR
fi

chown zeppelin:zeppelin -R $ZEPPELIN_INSTALL_DIR

# echo "log4j.rootLogger = INFO, stdout
# log4j.appender.stdout = org.apache.log4j.ConsoleAppender
# log4j.appender.stdout.layout = org.apache.log4j.PatternLayout
# log4j.appender.stdout.layout.ConversionPattern=%5p [%d] ({%t} %F[%M]:%L) - %m%n
# " > $ZEPPELIN_INSTALL_DIR/conf/log4j.properties

# sed -i 's# >> "${ZEPPELIN_OUTFILE}"##' $ZEPPELIN_INSTALL_DIR/bin/zeppelin-daemon.sh

# Create the zeppelin systemd service
echo "[Unit]
Description=Apache Zeppelin
Requires=network.target
After=network.target

[Service]
Type=forking
User=zeppelin
Group=zeppelin
ExecStart=$START_SCRIPT
ExecStop=$STOP_SCRIPT
Restart=on-failure
SyslogIdentifier=zeppelin

[Install]
WantedBy=multi-user.target" > $SERVICE_FILE

echo "export HBASE_HOME=/usr/local/hbase
export SPARK_HOME=/usr/local/spark
export HADOOP_CONF_DIR=/usr/local/hadoop/etc/hadoop
export PYTHONPATH=\$SPARK_HOME/python:\$SPARK_HOME/python/build:\$PYTHONPATH
export PYTHONPATH=\$SPARK_HOME/python/lib/py4j-0.8.2.1-src.zip:\$PYTHONPATH
export HBASE_RUBY_SOURCES=\$HBASE_HOME/lib/ruby/
export ZEPPELIN_LOG_DIR=$ZEPPELIN_LOG_DIR
export ZEPPELIN_PID_DIR=$ZEPPELIN_PID_DIR
export ZEPPELIN_WEBSOCKET_MAX_TEXT_MESSAGE_SIZE=104857600
" > $ZEPPELIN_INSTALL_DIR/conf/zeppelin-env.sh

# Reload unit files
systemctl daemon-reload 