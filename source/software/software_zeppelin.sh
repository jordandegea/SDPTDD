#!/bin/bash

# Fail if any command fail
set -e

# Load the shared provisioning script
source ./deploy_shared.sh

# Load Zeppelin install parameters
source ./zeppelin_shared.sh

if (($FORCE_INSTALL)) || ! [ -d $ZEPPELIN_INSTALL_DIR ]; then
  # Download Zeppelin
  echo "Zeppelin: downloading..."

  get_file "http://apache.mindstudios.com/zeppelin/$ZEPPELIN_NAME/$ZEPPELIN_FILENAME" $ZEPPELIN_FILENAME

  #Install in the right location
  echo "Zeppelin: Installing..."

  mv $ZEPPELIN_FILENAME /usr/local
  cd /usr/local/

  # Extract archive
  tar xf $ZEPPELIN_FILENAME

  # Fix ownership
  chown root:root -R $ZEPPELIN_NAME-bin-all
  
  # Install to the chosen location
  rm $ZEPPELIN_FILENAME
  rm -rf $ZEPPELIN_INSTALL_DIR
  mv $ZEPPELIN_NAME-bin-all $ZEPPELIN_INSTALL_DIR

  echo "export HBASE_HOME=/usr/local/hbase
export SPARK_HOME=/usr/local/spark
export HADOOP_CONF_DIR=/usr/local/hadoop/etc/hadoop
export PYTHONPATH=\$SPARK_HOME/python:\$SPARK_HOME/python/build:\$PYTHONPATH
export PYTHONPATH=\$SPARK_HOME/python/lib/py4j-0.8.2.1-src.zip:\$PYTHONPATH
export HBASE_RUBY_SOURCES=\$HBASE_HOME/lib/ruby/
export ZEPPELIN_LOG_DIR=$ZEPPELIN_LOG_DIR
export ZEPPELIN_PID_DIR=$ZEPPELIN_PID_DIR
" >> zeppelin/conf/zeppelin-env.sh

  echo "Zeppelin: successfully installed!" 1>&2
else
  echo "Zeppelin: already installed." 1>&2
fi
