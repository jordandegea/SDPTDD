# HBase parameters
JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64

HADOOP_VERSION=2.5.2
HADOOP_TGZ="hadoop-${HADOOP_VERSION}.tar.gz"
HADOOP_URL="http://apache.mindstudios.com/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz"
HADOOP_HOME="/usr/local/hadoop"

HBASE_VERSION=1.0.3
HBASE_LOG_DIR="/var/log/hbase"
HBASE_TGZ="hbase-${HBASE_VERSION}.tar.gz"
HBASE_URL="http://apache.mediamirrors.org/hbase/hbase-${HBASE_VERSION}/hbase-${HBASE_VERSION}-bin.tar.gz"
HBASE_HOME="/usr/local/hbase"

SERVICE_FILE="/etc/systemd/system/hbase@.service"
HADOOP_SERVICE_FILE="/etc/systemd/system/hadoop@.service"
