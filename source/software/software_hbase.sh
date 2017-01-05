#!/bin/bash

# Fail if any command fail
set -e

# Load the shared provisioning script
source ./deploy_shared.sh

# HBase parameters
source ./hbase_shared.sh

# Install Hadoop
if (($FORCE_INSTALL)) || ! [ -d $HADOOP_HOME ]; then
  echo "Hadoop: Installing..."
  get_file $HADOOP_URL $HADOOP_TGZ

  # Extract archive
  tar xf $HADOOP_TGZ

  # Fix ownership
  chown root:root -R hadoop-2.5.2
  rm -rf $HADOOP_HOME
  mv hadoop-2.5.2 $HADOOP_HOME
fi

# Download HBase
if (($FORCE_INSTALL)) || ! [ -d $HBASE_HOME ]; then
  echo "HBase: Installing..."
  get_file $HBASE_URL $HBASE_TGZ

  # Extract archive
  tar xf $HBASE_TGZ

  # Fix ownership
  chown root:root -R hbase-1.0.3
  
  # Install to the chosen location
  rm -rf $HBASE_HOME
  mv hbase-1.0.3 $HBASE_HOME
fi
