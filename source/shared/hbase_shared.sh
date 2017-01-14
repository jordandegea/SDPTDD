# HBase parameters
JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64

HADOOP_TGZ="hadoop-2.5.2.tar.gz"
HADOOP_URL="http://apache.mindstudios.com/hadoop/common/hadoop-2.5.2/hadoop-2.5.2.tar.gz"
HADOOP_HOME="/usr/local/hadoop"

HBASE_LOG_DIR="/var/log/hbase"
HBASE_TGZ="hbase-1.0.3.tar.gz"
HBASE_URL="http://apache.mediamirrors.org/hbase/hbase-1.0.3/hbase-1.0.3-bin.tar.gz"
HBASE_HOME="/usr/local/hbase"

SERVICE_FILE="/etc/systemd/system/hbase.service"
HADOOP_SERVICE_FILE="/etc/systemd/system/hadoop@.service"
START_SCRIPT="$HBASE_HOME/bin/our-start-hbase.sh"
STOP_SCRIPT="$HBASE_HOME/bin/our-stop-hbase.sh"
