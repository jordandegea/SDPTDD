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
<value>/home/hbase/dfs/data</value>
<final>true</final>
</property>
</configuration>" > $HADOOP_HOME/etc/hadoop/hdfs-site.xml

# Create the directory
mkdir -p /home/hbase/dfs
chown hbase:hbase -R /home/hbase/dfs

# Prepare the link to the shared directory
rm -f /home/hbase/dfs/name
ln -s /mnt/shared/name /home/hbase/dfs/name

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<?xml-stylesheet type=\"text/xsl\" href=\"configuration.xsl\"?>
<configuration>
<property>
<name>fs.defaultFS</name>
<value>hdfs://currentnamenode:9000</value>
</property>
</configuration>" > $HADOOP_HOME/etc/hadoop/core-site.xml

# Configure HBase
echo "HBase: Configuration"

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<configuration>
<property>
<name>hbase.cluster.distributed</name>
<value>true</value>
</property>

<property>
<name>hbase.rootdir</name>
<value>hdfs://currentnamenode:9000/hbase</value>
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

# Overwrite log4j
echo "log4j.rootLogger=INFO,console

# Logging Threshold
log4j.threshold=ALL

#
# console
# Add \"console\" to rootlogger above if you want to use this
#
log4j.appender.console=org.apache.log4j.ConsoleAppender
log4j.appender.console.target=System.err
log4j.appender.console.layout=org.apache.log4j.PatternLayout
log4j.appender.console.layout.ConversionPattern=%d{ISO8601} %-5p [%t] %c{2}: %m%n

# Custom Logging levels

log4j.logger.org.apache.zookeeper=INFO
#log4j.logger.org.apache.hadoop.fs.FSNamesystem=DEBUG
log4j.logger.org.apache.hadoop.hbase=INFO
# Make these two classes INFO-level. Make them DEBUG to see more zk debug.
log4j.logger.org.apache.hadoop.hbase.zookeeper.ZKUtil=INFO
log4j.logger.org.apache.hadoop.hbase.zookeeper.ZooKeeperWatcher=INFO
#log4j.logger.org.apache.hadoop.dfs=DEBUG
# Set this class to log INFO only otherwise its OTT
# Enable this to get detailed connection error/retry logging.
# log4j.logger.org.apache.hadoop.hbase.client.HConnectionManager\$HConnectionImplementation=TRACE
" >$HBASE_HOME/conf/log4j.properties

sed -i 's/ > ${logout}//' $HBASE_HOME/bin/hbase-daemon.sh
sed -i 's/ >> "$logout"//' $HBASE_HOME/bin/hbase-daemon.sh
sed -i 's/sleep 1; head "${logout}"//' $HBASE_HOME/bin/hbase-daemon.sh

echo "# Define some default values that can be overridden by system properties
hadoop.root.logger=INFO,console
hadoop.log.dir=.
hadoop.log.file=hadoop.log

# Define the root logger to the system property \"hadoop.root.logger\".
log4j.rootLogger=INFO,console

# Logging Threshold
log4j.threshold=ALL

# Null Appender
log4j.appender.NullAppender=org.apache.log4j.varia.NullAppender

#
# Rolling File Appender - cap space usage at 5gb.
#
hadoop.log.maxfilesize=256MB
hadoop.log.maxbackupindex=20

#
# console
#

log4j.appender.console=org.apache.log4j.ConsoleAppender
log4j.appender.console.target=System.err
log4j.appender.console.layout=org.apache.log4j.PatternLayout
log4j.appender.console.layout.ConversionPattern=%d{yy/MM/dd HH:mm:ss} %p %c{2}: %m%n
" >$HADOOP_HOME/etc/hadoop/log4j.properties

cp files/hadoop-daemon.sh $HADOOP_HOME/sbin/hadoop-daemon.sh
chmod 0755 $HADOOP_HOME/sbin/hadoop-daemon.sh

# Create the hadoop systemd service
echo "[Unit]
Description=Apache Hadoop %i
Requires=network.target
After=network.target

[Service]
Type=forking
User=root
Group=root
Environment=LOG_DIR=$HBASE_LOG_DIR
Environment=HADOOP_LOG_DIR=$HBASE_LOG_DIR
ExecStart=/usr/bin/sudo -u hbase -g hbase $HADOOP_HOME/sbin/hadoop-daemon.sh start %i
ExecStop=/usr/bin/sudo -u hbase -g hbase $HADOOP_HOME/sbin/hadoop-daemon.sh stop %i
Restart=on-failure
SyslogIdentifier=hadoop

[Install]
WantedBy=multi-user.target" >$HADOOP_SERVICE_FILE

mkdir -p /etc/systemd/system/hadoop@namenode.service.d
echo "[Service]
ExecStartPre=/bin/systemctl start drbd-primary
ExecStopPost=/bin/systemctl stop drbd-primary
" >/etc/systemd/system/hadoop@namenode.service.d/override.conf

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
ExecStop=$HBASE_HOME/bin/hbase-daemon.sh stop %i
Restart=on-failure
SyslogIdentifier=hbase

[Install]
WantedBy=multi-user.target" > $SERVICE_FILE

# Reload unit files
systemctl daemon-reload
