#!/bin/bash

# Fail if any command fail
set -eo pipefail

# Load the shared provisioning script
if [ -f './provisioning_shared.sh' ]; then
  source ./provisioning_shared.sh
else
  source /vagrant/provisioning_shared.sh
fi

# Tools
get_file () {
  url=$1 ; shift
  filename=$1 ; shift

  # Download file if needed
  if ! [ -f "/vagrant/resources/$filename" ]; then
    echo "Kafka: Downloading $url, this may take a while..."
    wget -q -O "/vagrant/resources/$filename" "$url"
  fi

  # Copy the cached file to the desired location (ie. pwd)
  cp "/vagrant/resources/$filename" "$filename"
}

# Installation parameters
KAFKA_VERSION=0.10.1.0
KAFKA_NAME=kafka_2.11-$KAFKA_VERSION
KAFKA_FILENAME=$KAFKA_NAME.tgz
KAFKA_INSTALL_DIR=/usr/local/kafka
KAFKA_CHECKSUM=45c7d032324e16c2e19a7d904a4d65c6

KAFKA_SERVICE_FILE=/etc/systemd/system/kafka.service

ZOOKEEPER_SERVICE_FILE=/etc/systemd/system/zookeeper.service

LOG4J_PATH=$KAFKA_INSTALL_DIR/config/log4j.properties

KAFKA_LOG_DIR=/var/log/kafka
ZOOKEEPER_LOG_DIR=/var/log/zookeeper

# Install Kafka
if (($FORCE_INSTALL)) || ! [ -d $KAFKA_INSTALL_DIR ]; then
  # Download Kafka
  echo "Kafka: downloading..." 1>&2

  get_file "http://apache.mindstudios.com/kafka/$KAFKA_VERSION/$KAFKA_FILENAME" $KAFKA_FILENAME

  # Check download integrity
  echo "$KAFKA_CHECKSUM *$KAFKA_FILENAME" >$KAFKA_FILENAME.md5
  md5sum -c $KAFKA_FILENAME.md5

  # Extract archive
  echo "Kafka: installing..." 1>&2
  tar xf $KAFKA_FILENAME

  # Remove the windows scripts from bin
  rm -rf $KAFKA_NAME/bin/windows

  # Install to the chosen location
  rm -rf $KAFKA_INSTALL_DIR
  mv $KAFKA_NAME $KAFKA_INSTALL_DIR

  # Symlink all files to /usr/local/bin
  for BINARY in $KAFKA_INSTALL_DIR/bin/*; do
    FN=/usr/local/bin/$(basename "$BINARY" .sh)
    echo "#!/bin/bash
$BINARY \"\$@\"" >"$FN"
    chmod +x "$FN"
  done

  # Cleanup
  rm -f $KAFKA_FILENAME $KAFKA_FILENAME.md5
else
  echo "Kafka: already installed." 1>&2
fi

# Create the kafka user if necessary
if ! id -u zookeeper >/dev/null 2>&1; then
  echo "Kafka: creating zookeeper user..." 1>&2
  useradd -m -s /bin/bash zookeeper
else
  echo "Kafka: zookeeper user already created." 1>&2
fi

# Check the log path for zookeeper
if ! [ -d $ZOOKEEPER_LOG_DIR ]; then
  mkdir -p $ZOOKEEPER_LOG_DIR
  chown zookeeper:zookeeper -R $ZOOKEEPER_LOG_DIR
fi

# Create the zookeeper systemd service
if (($FORCE_INSTALL)) || ! [ -f $ZOOKEEPER_SERVICE_FILE ]; then
  echo "Kafka: installing Zookeeper systemd unit..." 1>&2

  # Yes, KAFKA_HEAP_OPTS for ZOOKEEPER
  MORE_ENV=''
  if (($ENABLE_VAGRANT)); then
    MORE_ENV="Environment=KAFKA_HEAP_OPTS=-Xmx126M -Xms126M"
  fi

  # Install the unit file
  echo "[Unit]
Description=Apache Zookeeper
Requires=network.target
After=network.target

[Service]
Type=forking
User=zookeeper
Group=zookeeper
Environment=LOG_DIR=$ZOOKEEPER_LOG_DIR
$MORE_ENV
ExecStart=$KAFKA_INSTALL_DIR/bin/zookeeper-server-start.sh -daemon $KAFKA_INSTALL_DIR/config/zookeeper.properties
ExecStop=$KAFKA_INSTALL_DIR/bin/zookeeper-server-stop.sh
Restart=on-failure
SyslogIdentifier=zookeeper

[Install]
WantedBy=multi-user.target" >$ZOOKEEPER_SERVICE_FILE
else
  echo "Kafka: Zookeeper systemd unit already installed." 1>&2
fi

# Create the kafka user if necessary
if ! id -u kafka >/dev/null 2>&1; then
  echo "Kafka: creating user..." 1>&2
  useradd -m -s /bin/bash kafka
else
  echo "Kafka: user already created." 1>&2
fi

# Check the log path for kafka
if ! [ -d $KAFKA_LOG_DIR ]; then
  mkdir -p $KAFKA_LOG_DIR
  chown kafka:kafka -R $KAFKA_LOG_DIR
fi

# Create the kafka systemd service
if (($FORCE_INSTALL)) || ! [ -f $KAFKA_SERVICE_FILE ]; then
  echo "Kafka: installing Kafka systemd unit..." 1>&2

  MORE_ENV=''
  if (($ENABLE_VAGRANT)); then
    MORE_ENV="Environment=KAFKA_HEAP_OPTS=-Xmx256M -Xms256M"
  fi

  # Install the unit file
  echo "[Unit]
Description=Apache Kafka server (broker)
Requires=zookeeper.service network.target
After=zookeeper.service network.target

[Service]
Type=forking
User=kafka
Group=kafka
Environment=LOG_DIR=$KAFKA_LOG_DIR
$MORE_ENV
ExecStart=$KAFKA_INSTALL_DIR/bin/kafka-server-start.sh -daemon $KAFKA_INSTALL_DIR/config/server.properties
ExecStop=$KAFKA_INSTALL_DIR/bin/kafka-server-stop.sh
Restart=on-failure
SyslogIdentifier=kafka

[Install]
WantedBy=multi-user.target" >$KAFKA_SERVICE_FILE
else
  echo "Kafka: Kafka systemd unit already installed." 1>&2
fi

# Enable and start services
systemctl daemon-reload
systemctl enable zookeeper.service kafka.service
systemctl start zookeeper.service kafka.service
