#!/bin/bash

# Fail if any command fail
set -eo pipefail

# Load the shared provisioning script
if [ -f './provisioning_shared.sh' ]; then
  source ./provisioning_shared.sh
else
  source /vagrant/provisioning_shared.sh
fi

# echo "WARNING: HBase provisioning not yet implemented" 1>&2

# Download HBase
echo "Download HBase"
version="1.2.4"
tgz="hbase-$version-bin.tar.gz"
url="http://wwwftp.ciril.fr/pub/apache/hbase/$version/$tgz"
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
master="10.20.1.102"
servers="10.20.1.102, 10.20.1.101, 10.20.1.100"
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

JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
echo "
export JAVA_HOME=$JAVA_HOME
" >> hbase-env.sh

# Start hbase
echo "Start HBase"
if [ `hostname` = "worker3" ]
then
    /usr/lib/hbase/hbase-$version/bin/start-hbase.sh
fi
jps

