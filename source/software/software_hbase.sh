#!/bin/bash

# Fail if any command fail
set -eo pipefail

# Load the shared provisioning script
source ./deploy_shared.sh

# HBase parameters
source ./hbase_shared.sh

# Download Hadoop
if (($FORCE_INSTALL)) || ! [ -d $HADOOP_HOME ]; then
    echo "Hadoop: Download"
    get_file $HADOOP_URL $HADOOP_TGZ
    tar xf $HADOOP_TGZ
    rm -rf $HADOOP_HOME
    mv hadoop-2.5.2 $HADOOP_HOME
fi

# Download HBase
if (($FORCE_INSTALL)) || ! [ -d $HBASE_HOME ]; then
    echo "HBase: Download"
    get_file $HBASE_URL $HBASE_TGZ
    tar xf $HBASE_TGZ
    rm -rf $HBASE_HOME
    mv hbase-1.0.3 $HBASE_HOME
fi
