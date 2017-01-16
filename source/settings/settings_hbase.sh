#!/bin/bash

# Fail if any command fail
set -e

# Load the shared provisioning script
source ./deploy_shared.sh

# HBase parameters
source ./hbase_shared.sh

# Read HBase quorum from args
while getopts ":vfq:" opt; do
    case "$opt" in
        q)
        HBASE_QUORUM="$OPTARG"
        ;;
    esac
done
OPTIND=1

# Configure Hadoop
echo "Hadoop: Configuration"

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

chown hbase:hbase -R $HBASE_HOME
chown hbase:hbase -R $HADOOP_HOME

# Deploy SSH config
rm -rf ~/hbase/.ssh
if (($ENABLE_VAGRANT)); then
  cp -r ~vagrant/.ssh ~hbase/.ssh
else
  cp -r ~xnet/.ssh ~hbase/.ssh
fi
chown hbase:hbase -R ~hbase/.ssh

# Remove previous config
sed -i '/# BEGIN HBASE CONF/,/# END HBASE CONF/d' $HADOOP_HOME/etc/hadoop/hadoop-env.sh

echo "# BEGIN HBASE CONF
export JAVA_HOME=$JAVA_HOME
export HADOOP_LOG_DIR=$HBASE_LOG_DIR
# END HBASE CONF" >> $HADOOP_HOME/etc/hadoop/hadoop-env.sh

# We have 3 machines, we can have a replication factor of 3
echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<?xml-stylesheet type=\"text/xsl\" href=\"configuration.xsl\"?>
<configuration>
<property>
<name>dfs.replication</name>
<value>3</value>
</property>

<property>
<name>dfs.safemode.threshold.pct</name>
<value>0</value>
</property>

<property>
<name>dfs.name.dir</name>
<value>/home/hbase/dfs/name</value>
<final>true</final>
</property>

<property>
<name>dfs.data.dir</name>
<value>/home/hbase/dfs/name/data/</value>
<final>true</final>
</property>
</configuration>" > $HADOOP_HOME/etc/hadoop/hdfs-site.xml

# Create the directory
mkdir -p /home/hbase/dfs
chown hbase:hbase -R /home/hbase/dfs

# TODO: fix hardcoding
echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<?xml-stylesheet type=\"text/xsl\" href=\"configuration.xsl\"?>
<configuration>
<property>
<name>fs.defaultFS</name>
<value>hdfs://worker1:9000</value>
</property>
</configuration>" > $HADOOP_HOME/etc/hadoop/core-site.xml

# Configure HBase
echo "HBase: Configuration"

# TODO: fix hardcoding
echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<configuration>
<property>
<name>hbase.cluster.distributed</name>
<value>true</value>
</property>

<property>
<name>hbase.rootdir</name>
<value>hdfs://worker1:9000/hbase</value>
</property>

<property>
<name>hbase.zookeeper.quorum</name>
<value>$HBASE_QUORUM</value>
</property>
</configuration>
" > $HBASE_HOME/conf/hbase-site.xml

# Remove previous config
sed -i '/# BEGIN HBASE CONF/,/# END HBASE CONF/d' $HBASE_HOME/conf/hbase-env.sh

echo "# BEGIN HBASE CONF
export HBASE_MANAGES_ZK=false
export JAVA_HOME=$JAVA_HOME
export HBASE_LOG_DIR=$HBASE_LOG_DIR
# END HBASE CONF" >> $HBASE_HOME/conf/hbase-env.sh

# Create the hadoop systemd service
echo "[Unit]
Description=Apache Hadoop %i
Requires=network.target
After=network.target

[Service]
Type=forking
User=hbase
Group=hbase
Environment=LOG_DIR=$HBASE_LOG_DIR
Environment=HADOOP_LOG_DIR=$HBASE_LOG_DIR
ExecStart=$HADOOP_HOME/sbin/hadoop-daemon.sh start %i
ExecStop=-$HADOOP_HOME/sbin/hadoop-daemon.sh stop %i
Restart=on-failure
SyslogIdentifier=hadoop

[Install]
WantedBy=multi-user.target" >$HADOOP_SERVICE_FILE

# Create the hbase systemd service
echo "[Unit]
Description=Apache HBase %i
Requires=network.target
After=network.target

[Service]
Type=forking
User=hbase
Group=hbase
Environment=LOG_DIR=$HBASE_LOG_DIR
Environment=HBASE_LOG_DIR=$HBASE_LOG_DIR
Environment=HADOOP_LOG_DIR=$HBASE_LOG_DIR
ExecStart=$HBASE_HOME/bin/hbase-daemon.sh start %i
ExecStop=-$HBASE_HOME/bin/hbase-daemon.sh stop %i
Restart=on-failure
SyslogIdentifier=hbase

[Install]
WantedBy=multi-user.target" > $SERVICE_FILE

# Reload unit files
systemctl daemon-reload
