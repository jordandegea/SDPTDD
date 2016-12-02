#!/bin/bash

# Fail if any command fail
set -eo pipefail

# This script must be run as root.
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

# echo "WARNING: HBase provisioning not yet implemented" 1>&2

# Download HBase
echo "Download HBase"
version="1.2.4"
tgz="hbase-$version-bin.tar.gz"
url="http://wwwftp.ciril.fr/pub/apache/hbase/stable/$tgz"
cached_file="/vagrant/resources/$tgz"
if [ ! -e $cached_file ]
then
    echo "Downloading $tgz from $url to $cached_file"
    wget -nv -O $cached_file $url
fi
libpath="/usr/lib/hbase"
mkdir -p $libpath
tar -oxzf $cached_file -C $libpath

# Configure HBase
echo "Configure HBase"
export HBASE_HOME="/usr/lib/hbase/hbase-$version"
cd $libpath/hbase-$version/conf
master="10.20.1.100"
servers="10.20.1.100, 10.20.1.101, 10.20.1.102"
echo "<?xml version=\"1.0\"?>
<?xml-stylesheet type=\"text/xsl\" href=\"configuration.xsl\"?>
<configuration>
 
  <property>
    <name>hbase.rootdir</name>
    <value>hdfs://$master:9000/hbase</value>
  </property>
 
   <property>
    <name>hbase.cluster.distributed</name>
    <value>true</value>
  </property>
 
  <property>
    <name>hbase.zookeeper.property.dataDir</name>
    <value>hdfs://$master:9000/zookeeper</value>
  </property>
 
  <property>
    <name>hbase.zookeeper.quorum</name>
    <value>$servers</value>
  </property>
 
</configuration>
" > hbase-site.xml

# File + cut is used to expand *
JAVA_HOME=$(file -0 /usr/lib/jvm/java-1.8.*-openjdk-* | cut -d '' -f 1)
echo $JAVA_HOME
echo "
export JAVA_HOME=$JAVA_HOME
" >> hbase-env.sh

# Start hbase
echo "Start HBase"
ip=`ifconfig eth1 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'`
echo $ip
echo "lol"
if [ $ip = $master ]
then
    /usr/lib/hbase/hbase-$version/bin/start-hbase.sh
fi

