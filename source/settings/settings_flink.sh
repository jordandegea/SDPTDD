#!/bin/bash

# Fail if any command fail
set -e

# Load the shared provisioning script
source ./deploy_shared.sh

# Load flink setup parameters
source ./flink_shared.sh

# Read HBase and ZooKeeper quorum from args
while getopts ":vft:q:F:" opt; do
  case "$opt" in
    q)
      HBASE_QUORUM="$OPTARG"
    ;;
    F)
      FLINK_BOOTSTRAP="$OPTARG"
    ;;
  esac
done
OPTIND=1

# Create the flink user if necessary
if ! id -u flink >/dev/null 2>&1; then
  echo "Flink: creating flink user..." 1>&2
  useradd -m -s /bin/bash flink
else
  echo "Flink: flink user already created." 1>&2
fi

# Check the log path for zookeeper
if ! [ -d $FLINK_LOG_DIR ]; then
  mkdir -p $FLINK_LOG_DIR
  chown flink:flink -R $FLINK_LOG_DIR
fi

# Create systemd unit for flink service
echo "Flink: installing Flink systemd unit..." 1>&2

echo "jobmanager.rpc.address: jobmanager_replace_me
jobmanager.rpc.port: 6123
jobmanager.heap.mb: 256
taskmanager.heap.mb: 512
taskmanager.numberOfTaskSlots: 20
taskmanager.memory.preallocate: false
parallelism.default: 2
jobmanager.web.port: 8081
" > ${FLINK_CONF_FILE}.tpl

sed 's#jobmanager_replace_me#localhost#' ${FLINK_CONF_FILE}.tpl > $FLINK_CONF_FILE

# Delete all previous flink units
set +e
rm -rf /etc/systemd/system/flink*.service
set -e

echo "[Unit]
Description=Apache Flink %i
Requires=network.target
After=network.target

[Service]
Type=forking
User=flink
Group=flink
Environment=FLINK_LOG_DIR=$FLINK_LOG_DIR
Environment=FLINK_PID_DIR=$FLINK_LOG_DIR
ExecStart=/bin/bash $FLINK_INSTALL_DIR/bin/%i.sh start cluster
ExecStop=/bin/bash $FLINK_INSTALL_DIR/bin/%i.sh stop
PIDFile=$FLINK_LOG_DIR/flink-flink-%i.pid
Restart=on-failure
SyslogIdentifier=flink@%i

[Install]
WantedBy=multi-user.target" >$FLINK_SERVICE_FILE

# Create systemd unit for flink service

# Create the services
echo "Flink: installing Flink city (hbase) systemd template unit..." 1>&2

# Install the unit file
echo "[Unit]
Description=Flink bridge (%i)
Requires=network.target
After=network.target

[Service]
User=flink
Group=flink
Environment=FLINK_LOG_DIR=$FLINK_LOG_DIR/%i
ExecStart=$FLINK_INSTALL_DIR/bin/flink run $FLINK_INSTALL_DIR/KafkaHbaseBridge.jar --port 9000 --topic %i --bootstrap.servers $FLINK_BOOTSTRAP --zookeeper.connect localhost:2181 --group.id %iconsumer --hbasetable %i_tweets --hbasequorum $HBASE_QUORUM --hbaseport 2181
SyslogIdentifier=flink_city@%i

[Install]
WantedBy=multi-user.target" >/etc/systemd/system/flink_city@.service

# Create the services
echo "Flink: installing Flink city (console) systemd template unit..." 1>&2

# Install the unit file
echo "[Unit]
Description=Flink bridge (%i)
Requires=network.target
After=network.target

[Service]
User=flink
Group=flink
Environment=FLINK_LOG_DIR=$FLINK_LOG_DIR/%i
ExecStart=$FLINK_INSTALL_DIR/bin/flink run $FLINK_INSTALL_DIR/KafkaConsoleBridge.jar --port 9000 --topic %i --bootstrap.servers $FLINK_BOOTSTRAP --zookeeper.connect localhost:2181 --group.id %iconsumer --hbasetable %i_tweets --hbasequorum $HBASE_QUORUM --hbaseport 2181
SyslogIdentifier=flink_console@%i

[Install]
WantedBy=multi-user.target" >/etc/systemd/system/flink_city_console@.service

# Create the services
echo "Flink: installing Flink fake producer systemd unit..." 1>&2

echo "[Unit]
Description=Flink bridge producer
Requires=network.target
After=network.target

[Service]
User=flink
Group=flink
Environment=FLINK_LOG_DIR=$FLINK_LOG_DIR/flink_producer_fake
WorkingDirectory=$FLINK_INSTALL_DIR
ExecStart=$FLINK_INSTALL_DIR/bin/flink run $FLINK_INSTALL_DIR/FakeTwitterProducer.jar 1 $FLINK_BOOTSTRAP
SyslogIdentifier=flink_producer_fake

[Install]
WantedBy=multi-user.target" >/etc/systemd/system/flink_producer_fake.service

systemctl daemon-reload
