#!/bin/bash

# Fail if any command fail
set -eo pipefail

# Load the shared provisioning script
if [ -f './provisioning_shared.sh' ]; then
	source ./provisioning_shared.sh
else
	source /vagrant/provisioning_shared.sh
fi

filename="flink-1.1.3"
bindir="/opt/$filename/bin"

function downloadFlink {
	filename="$filename.tgz"
	echo "Flink: downloading..."
	get_file "http://apache.mirrors.ovh.net/ftp.apache.org/dist/flink/flink-1.1.3/flink-1.1.3-bin-hadoop1-scala_2.10.tgz" $filename
}

echo "Setting up Flink"

downloadFlink
tar -oxzf $filename -C /opt

# Parameters
FLINK_LOG_DIR=/var/log/flink
FLINK_SERVICE_FILE=/etc/systemd/system/flink.service
FLINK_INSTALL_DIR=/opt/$(basename "$filename" .tgz)
FLINK_BRIDGE_SERVICE_FILE=/etc/systemd/system/flinkbridge.service

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

# Deploy jar
cp KafkaHbaseBridge.jar /opt
cp FakeTwitterProducer.jar /opt

# Create systemd unit for flink service

# Create the services
echo "Flink: installing Flink cities systemd unit..." 1>&2

while getopts ":t:" opt; do
    case "$opt" in
        t)
            TOPIC_NAME="$OPTARG"

            # Install the unit file
            # TODO: Use -H
            echo "[Unit]
Description=Flink bridge ($TOPIC_NAME)
Requires=network.target flink.service hbase.service
After=network.target flink.service hbase.service

[Service]
Type=oneshot
User=flink
Group=flink
Environment=FLINK_LOG_DIR=$FLINK_LOG_DIR
ExecStart=$FLINK_INSTALL_DIR/bin/flink run /opt/KafkaHbaseBridge.jar --port 9000 --topic $TOPIC_NAME --bootstrap.servers localhost:9092 --zookeeper.connect localhost:2181 --group.id parisconsumer --hbasetable $TOPIC_NAME --hbasequorum worker1,worker2,worker3 --hbaseport 2181
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
Type=oneshot
User=flink
Group=flink
Environment=FLINK_LOG_DIR=$FLINK_LOG_DIR
ExecStart=$FLINK_INSTALL_DIR/bin/flink run /opt/FakeTwitterProducer.jar 1 localhost:9092
SyslogIdentifier=flink_producer_fake

[Install]
WantedBy=multi-user.target" >/etc/systemd/system/flink_producer_fake.service

systemctl daemon-reload
