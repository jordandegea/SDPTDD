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
START_SCRIPT="$HBASE_HOME/bin/start-hbase.sh"
STOP_SCRIPT="$HBASE_HOME/bin/stop-hbase.sh"

# Create the hbase user if necessary
if ! id -u hbase >/dev/null 2>&1; then
  echo "HBase: creating user..." 1>&2
  useradd -m -s /bin/bash hbase
  sudo passwd -d hbase
else
  echo "HBase: user already created." 1>&2
fi

# Check the log path for hbase
if ! [ -d $HBASE_LOG_DIR ]; then
  mkdir -p $HBASE_LOG_DIR
  chown hbase:hbase -R $HBASE_LOG_DIR
fi

# Deploy SSH config
rm -rf ~/hbase/.ssh
if (($ENABLE_VAGRANT)); then
  cp -r ~vagrant/.ssh ~hbase/.ssh
else
  cp -r ~xnet/.ssh ~hbase/.ssh
fi
chown hbase:hbase -R ~hbase/.ssh

# Get options
MASTER=""
SLAVES=""
while getopts ":m:s:M" opt; do
  case "$opt" in
    m)
      MASTER="$OPTARG"
      ;;
    s)
      SLAVES="$OPTARG"
      ;;
    :)
      echo "Missing argument: the option $opt needs an \
          argument." >&2
      ;;
  esac
done

# Download Hadoop
if (($FORCE_INSTALL)) || ! [ -d $HADOOP_HOME ]; then
    echo "Hadoop: Download"
    get_file $HADOOP_URL $HADOOP_TGZ
    tar -oxzf /vagrant/resources/$HADOOP_TGZ -C /vagrant/resources
    mv /vagrant/resources/hadoop-$HADOOP_VERSION $HADOOP_HOME
fi

# Configure Hadoop
echo "Hadoop: Configuration"

echo "
export JAVA_HOME=$JAVA_HOME
export HADOOP_OPTS=\"-Djava.library.path=$HADOOP_HOME/lib/native\"
" >> $HADOOP_HOME/etc/hadoop/hadoop-env.sh

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<?xml-stylesheet type=\"text/xsl\" href=\"configuration.xsl\"?>
<configuration>
  <property>
    <name>dfs.replication</name>
    <value>0</value>
  </property>

  <property>
    <name>dfs.namenode.edits.dir</name>
    <value>file:///home/hbase/hadoopdata/hdfs/namenode</value>
  </property>

  <property>
    <name>dfs.datanode.data.dir</name>
    <value>file:///home/hbase/hadoopdata/hdfs/datanode</value>
  </property>
</configuration>" > $HADOOP_HOME/etc/hadoop/hdfs-site.xml

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<?xml-stylesheet type=\"text/xsl\" href=\"configuration.xsl\"?>
<configuration>
  <property>
    <name>fs.default.name</name>
    <value>hdfs://$MASTER:9OOO</value>
  </property>
  <property>
    <name>hadoop.tmp.dir</name>
    <value>/home/hbase/hadoopdata/tmp</value>
  </property>
</configuration>" > $HADOOP_HOME/etc/hadoop/core-site.xml

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<?xml-stylesheet type=\"text/xsl\" href=\"configuration.xsl\"?>
<configuration>
  <property>
    <name>mapreduce.framework.name</name>
    <value>yarn</value>
  </property>
</configuration>" > $HADOOP_HOME/etc/hadoop/mapred-site.xml

echo "export JAVA_HOME=$JAVA_HOME
export HBASE_MANAGES_ZK=false
" >> $HBASE_HOME/conf/hbase-env.sh

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<configuration>
  <property>
    <name>hbase.zookeeper.property.dataDir</name>
    <value>/tmp/zookeeper</value>
  </property>
</configuration>
" > $HBASE_HOME/conf/hbase-site.xml

echo "[Unit]
Description=Apache HBase
Requires=network.target zookeeper.service
After=network.target zookeeper.service

[Service]
Type=forking
User=hbase
Group=hbase
Environment=HBASE_LOG_DIR=$HBASE_LOG_DIR
Environment=HADOOP_HOME=$HADOOP_HOME
Environment=HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
Environment=HADOOP_INSTALL=$HADOOP_HOME
Environment=HADOOP_MAPRED_HOME=$HADOOP_HOME
Environment=HADOOP_COMMON_HOME=$HADOOP_HOME
Environment=HADOOP_HDFS_HOME=$HADOOP_HOME
Environment=YARN_HOME=$HADOOP_HOME
Environment=HADOOP_COMMON_LIB_NATIVE_DIR=$HADOOP_HOME/lib/native
Environment=PATH=$PATH:$HADOOP_HOME/sbin:$HADOOP_HOME/bin
ExecStart=$START_SCRIPT
ExecStop=$STOP_SCRIPT
Restart=on-failure
SyslogIdentifier=hbase

[Install]
WantedBy=multi-user.target" >$SERVICE_FILE

# Reload unit files
systemctl daemon-reload
