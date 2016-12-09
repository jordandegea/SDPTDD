#!/bin/bash

# Fail if any command fail
set -eo pipefail

# Load the shared provisioning script
source ./provisioning_shared.sh

JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64

HADOOP_TGZ="hadoop-2.5.2.tar.gz"
HADOOP_URL="http://apache.mindstudios.com/hadoop/common/hadoop-2.5.2/hadoop-2.5.2.tar.gz"
HADOOP_HOME="/usr/local/hadoop"

HBASE_LOG_DIR="/var/log/hbase"
HBASE_TGZ="hbase.tar.gz"
HBASE_URL="http://apache.mediamirrors.org/hbase/hbase-1.0.3/hbase-1.0.3-bin.tar.gz"
HBASE_HOME="/usr/local/hbase"

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

# Download Hadoop
if (($FORCE_INSTALL)) || ! [ -d $HADOOP_HOME ]; then
	echo "Hadoop: Download"
	get_file $HADOOP_URL $HADOOP_TGZ
	tar xf $HADOOP_TGZ -C /opt
	rm -rf $HADOOP_HOME
	mv /opt/hadoop-2.5.2 $HADOOP_HOME
fi

# Download HBase
if (($FORCE_INSTALL)) || ! [ -d $HBASE_HOME ]; then
    echo "HBase: Download"
    get_file $HBASE_URL $HBASE_TGZ
    tar xf $HBASE_TGZ

    rm -rf $HBASE_HOME
    mv hbase-1.0.3 $HBASE_HOME
fi

# Configure Hadoop
echo "Hadoop: Configuration"

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
<name>hbase.rootdir</name>
<value>hdfs://localhost:9000/hbase</value>
</property>

<property>
<name>hbase.zookeeper.quorum</name>
<value>worker1,worker2,worker3</value>
</property>
</configuration>
" > $HBASE_HOME/conf/hbase-site.xml

echo "
export JAVA_HOME=$JAVA_HOME
export HBASE_MANAGES_ZK=false
export HBASE_LOG_DIR=$HBASE_LOG_DIR
" >> $HBASE_HOME/conf/hbase-env.sh

if (($FORCE_INSTALL)) || ! [ -f $START_SCRIPT ]; then
	echo "#!/bin/bash
$HADOOP_HOME/sbin/start-dfs.sh
$HBASE_HOME/bin/start-hbase.sh" > $START_SCRIPT
	chmod +x $START_SCRIPT
fi
if (($FORCE_INSTALL)) || ! [ -f $STOP_SCRIPT ]; then
	echo "#!/bin/bash
$HBASE_HOME/bin/stop-hbase.sh
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
Environment=HBASE_LOG_DIR=$HBASE_LOG_DIR
ExecStart=$START_SCRIPT
ExecStop=$STOP_SCRIPT
Restart=on-failure
SyslogIdentifier=hbase

[Install]
WantedBy=multi-user.target" > $SERVICE_FILE
fi

# Reload unit files
systemctl daemon-reload
