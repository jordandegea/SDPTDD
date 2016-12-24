#!/bin/bash

# Fail if any command fail
set -eo pipefail

# Load the shared provisioning script
source ./deploy_shared.sh

# HBase parameters
source ./hbase_shared.sh

# Read HBase quorum from args
while getopts ":q:" opt; do
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

# Deploy SSH config
rm -rf ~/hbase/.ssh
if (($ENABLE_VAGRANT)); then
  cp -r ~vagrant/.ssh ~hbase/.ssh
else
  cp -r ~xnet/.ssh ~hbase/.ssh
fi
chown hbase:hbase -R ~hbase/.ssh

echo "
export JAVA_HOME=$JAVA_HOME
" >> $HADOOP_HOME/etc/hadoop/hadoop-env.sh

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<?xml-stylesheet type=\"text/xsl\" href=\"configuration.xsl\"?>
<configuration>
<property>
<name>dfs.replication</name>
<value>1</value>
</property>
</configuration>" > $HADOOP_HOME/etc/hadoop/hdfs-site.xml

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<?xml-stylesheet type=\"text/xsl\" href=\"configuration.xsl\"?>
<configuration>
<property>
<name>fs.defaultFS</name>
<value>hdfs://localhost:9000</value>
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
<name>hbase.root</name>
<value>hdfs://localhost:9000/hbase</value>
</property>

<property>
<name>hbase.zookeeper.quorum</name>
<value>$HBASE_QUORUM</value>
</property>
</configuration>
" > $HBASE_HOME/conf/hbase-site.xml

echo "
export HBASE_MANAGES_ZK=false
export JAVA_HOME=$JAVA_HOME
export HBASE_LOG_DIR=$HBASE_LOG_DIR
" >> $HBASE_HOME/conf/hbase-env.sh

echo "#!/bin/bash
$HADOOP_HOME/sbin/start-dfs.sh
$HBASE_HOME/bin/hbase-daemons.sh {start,stop} zookeeper
$HBASE_HOME/bin/start-hbase.sh" > $START_SCRIPT
chmod +x $START_SCRIPT

echo "#!/bin/bash
$HADOOP_HOME/sbin/stop-dfs.sh
$HBASE_HOME/bin/stop-hbase.sh" > $STOP_SCRIPT
chmod +x $STOP_SCRIPT

# Create the hbase systemd service
echo "[Unit]
Description=Apache HBase
Requires=network.target
After=network.target

[Service]
Type=forking
User=hbase
Group=hbase
Environment=LOG_DIR=$HBASE_LOG_DIR
Environment=HBASE_LOG_DIR=$HBASE_LOG_DIR
ExecStart=$START_SCRIPT
ExecStop=$STOP_SCRIPT
Restart=on-failure
SyslogIdentifier=hbase

[Install]
WantedBy=multi-user.target" > $SERVICE_FILE

# Reload unit files
systemctl daemon-reload
