#!/bin/bash

# Fail if any command fail
set -eo pipefail

# Load the shared provisioning script
source ./deploy_shared.sh

# Load flink setup parameters
source ./flink_shared.sh

# Read HBase and ZooKeeper quorum from args
while getopts ":q:F:" opt; do
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

echo "jobmanager.rpc.address: localhost
jobmanager.rpc.port: 6123
jobmanager.heap.mb: 256
taskmanager.heap.mb: 512
taskmanager.numberOfTaskSlots: 4
taskmanager.memory.preallocate: false
parallelism.default: 4
jobmanager.web.port: 8081
" > ${FLINK_CONF_FILE}


echo "[Unit]
Description=Apache Flink
Requires=network.target
After=network.target

[Service]
Type=forking
User=flink
Group=flink
Environment=FLINK_LOG_DIR=$FLINK_LOG_DIR
ExecStart=$FLINK_INSTALL_DIR/bin/start-local.sh
ExecStop=$FLINK_INSTALL_DIR/bin/stop-local.sh
Restart=on-failure
SyslogIdentifier=flink

[Install]
WantedBy=multi-user.target" >$FLINK_SERVICE_FILE

# Create systemd unit for flink service

# Create the services
echo "Flink: installing Flink cities systemd unit..." 1>&2

while getopts ":t:" opt; do
    case "$opt" in
        t)
            TOPIC_NAME="$OPTARG"

            # Install the unit file
            echo "[Unit]
Description=Flink bridge ($TOPIC_NAME)
Requires=network.target flink.service hbase.service
After=network.target flink.service hbase.service

[Service]
Type=forking
User=flink
Group=flink
Environment=FLINK_LOG_DIR=$FLINK_LOG_DIR/$TOPIC_NAME
ExecStart=/bin/bash -c 'nohup $FLINK_INSTALL_DIR/bin/flink run $FLINK_INSTALL_DIR/KafkaConsoleBridge.jar --port 9000 --topic $TOPIC_NAME --bootstrap.servers $FLINK_BOOTSTRAP --zookeeper.connect localhost:2181 --group.id parisconsumer --hbasetable $TOPIC_NAME --hbasequorum $HBASE_QUORUM --hbaseport 2181 &'
SyslogIdentifier=flink_$TOPIC_NAME

[Install]
WantedBy=multi-user.target" >/etc/systemd/system/flink_$TOPIC_NAME.service
      ;;
  esac
done

# Create the services
echo "Flink: installing Flink fake producer systemd unit..." 1>&2

echo "[Unit]
Description=Flink bridge producer
Requires=network.target flink.service hbase.service
After=network.target flink.service hbase.service

[Service]
Type=forking
User=flink
Group=flink
Environment=FLINK_LOG_DIR=$FLINK_LOG_DIR/flink_producer_fake
WorkingDirectory=$FLINK_INSTALL_DIR
ExecStart=/bin/bash -c 'nohup $FLINK_INSTALL_DIR/bin/flink run $FLINK_INSTALL_DIR/FakeTwitterProducer.jar 1 $FLINK_BOOTSTRAP &'
SyslogIdentifier=flink_producer_fake

[Install]
WantedBy=multi-user.target" >/etc/systemd/system/flink_producer_fake.service

systemctl daemon-reload
