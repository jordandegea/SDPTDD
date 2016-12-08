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

HADOOP_VERSION="2.7.3"
HADOOP_TGZ="hadoop-$HADOOP_VERSION.tar.gz"
HADOOP_URL="http://apache.mediamirrors.org/hadoop/common/hadoop-$HADOOP_VERSION/$HADOOP_TGZ"
HADOOP_HOME="/usr/local/hadoop"

HBASE_VERSION="1.2.4"
HBASE_LOG_DIR="/var/log/hbase"
HBASE_TGZ="hbase-$HBASE_VERSION-bin.tar.gz"
HBASE_URL="http://wwwftp.ciril.fr/pub/apache/hbase/$HBASE_VERSION/$HBASE_TGZ"
HBASE_HOME="/usr/lib/hbase"

SERVICE_FILE="/etc/systemd/system/hbase.service"
START_SCRIPT="/usr/local/bin/hstart"
STOP_SCRIPT="/usr/local/bin/hstop"

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

# Get options
IS_MASTER=0
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
    M)
      IS_MASTER=1
      ;;
    :)
      echo "Missing argument: the option $opt needs an \
          argument." >&2
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
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

# if (($FORCE_INSTALL)) || ! [ -d /home/hbase/hbasebashrc ]; then
#     echo "export HADOOP_HOME=$HADOOP_HOME
# export HADOOP_CONF_DIR=\$HADOOP_HOME/etc/hadoop
# export HADOOP_INSTALL=\$HADOOP_HOME
# export HADOOP_MAPRED_HOME=\$HADOOP_HOME
# export HADOOP_COMMON_HOME=\$HADOOP_HOME
# export HADOOP_HDFS_HOME=\$HADOOP_HOME
# export YARN_HOME=\$HADOOP_HOME
# export HADOOP_COMMON_LIB_NATIVE_DIR=\$HADOOP_HOME/lib/native
# export PATH=\$PATH:\$HADOOP_HOME/sbin:\$HADOOP_HOME/bin" >> /home/hbase/hbasebashrc
# fi 

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

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<?xml-stylesheet type=\"text/xsl\" href=\"configuration.xsl\"?>
<configuration>
 
  <property>
    <name>hbase.rootdir</name>
    <value>hdfs://$MASTER:9000/hbase</value>
  </property>
 
   <property>
    <name>hbase.cluster.distributed</name>
    <value>true</value>
  </property>
 
  <property>
    <name>hbase.zookeeper.property.dataDir</name>
    <value>hdfs://$MASTER:9000/zookeeper</value>
  </property>
 
  <property>
    <name>hbase.zookeeper.quorum</name>
    <value>$MASTER $SLAVES</value>
  </property>
 
</configuration>
" > hbase-site.xml

rm -f regionservers
for node in $SLAVES $MASTER; do
    echo $node >> regionservers
done

echo "
export JAVA_HOME=$JAVA_HOME
" >> hbase-env.sh

if (($IS_MASTER)); then
    echo "Hadoop-Hbase: Master"
    if (($FORCE_INSTALL)) || ! [ -f $START_SCRIPT ]; then
        echo "rm -rf /home/hbase/hadoopdata/tmp
hdfs namenode -format
hdfs getconf -namenodes
$HADOOP_HOME/sbin/start-dfs.sh
$HADOOP_HOME/sbin/start-yarn.sh
$HBASE_HOME/bin/start-hbase.sh" > $START_SCRIPT
        chmod +x $START_SCRIPT
    fi
    if (($FORCE_INSTALL)) || ! [ -f $STOP_SCRIPT ]; then
        echo "$HBASE_HOME/bin/stop-hbase.sh
$HADOOP_HOME/sbin/stop-yarn.sh
$HADOOP_HOME/sbin/stop-dfs.sh" > $STOP_SCRIPT
        chmod +x $STOP_SCRIPT
    fi

    # Create the hbase systemd service
    if (($FORCE_INSTALL)) || ! [ -f $SERVICE_FILE ]; then
        echo "[Unit]
Description=Apache HBase
Requires=network.target
After=network.target

[Service]
Type=forking
User=hbase
Group=hbase
Environment=LOG_DIR=$HBASE_LOG_DIR
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
WantedBy=multi-user.target" > $SERVICE_FILE
    fi
fi

# Reload unit files
systemctl daemon-reload

if (($IS_MASTER)) && (($ENABLE_VAGRANT)); then
    systemctl enable hbase.service
    systemctl start hbase.service
fi
