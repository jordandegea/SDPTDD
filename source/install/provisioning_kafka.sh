#!/bin/bash

# Fail if any command fail
set -eo pipefail

# This script must be run as root.
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

# Detect the environment
ENABLE_VAGRANT=0
while getopts ":v" opt; do
  case $opt in
    v)
      echo "Kafka: Running in vagrant mode." 1>&2
      ENABLE_VAGRANT=1
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done

# Tools
get_file () {
  url=$1 ; shift
  filename=$1 ; shift

  wget -q -O "$filename" "$url"
}

# Installation parameters
KAFKA_VERSION=0.10.1.0
KAFKA_NAME=kafka_2.11-$KAFKA_VERSION
KAFKA_FILENAME=$KAFKA_NAME.tgz
KAFKA_INSTALL_DIR=/usr/local/kafka
KAFKA_CHECKSUM=45c7d032324e16c2e19a7d904a4d65c6

KAFKA_SERVICE_FILE=/etc/systemd/system/kafka.service
KAFKA_CONF_DIR=/etc/kafka
KAFKA_CONF_FILE=$KAFKA_CONF_DIR/kafka.conf

ZOOKEEPER_SERVICE_FILE=/etc/systemd/system/zookeeper.service
ZOOKEEPER_CONF_DIR=/etc/zookeeper
ZOOKEEPER_CONF_FILE=$ZOOKEEPER_CONF_DIR/zookeeper.conf

LOG4J_PATH=$KAFKA_INSTALL_DIR/config/log4j.properties

KAFKA_LOG_DIR=/var/log/kafka
ZOOKEEPER_LOG_DIR=/var/log/zookeeper

# Install Kafka
if ! [ -d $KAFKA_INSTALL_DIR ]; then
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
  ln -s $KAFKA_INSTALL_DIR/bin/* /usr/local/bin

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

# Ensure we have a kafka config setup
if ! [ -d $ZOOKEEPER_CONF_DIR ]; then
  mkdir -p $ZOOKEEPER_CONF_DIR
fi

if ! [ -f $ZOOKEEPER_CONF_FILE ]; then
  echo "Kafka: installed Zookeeper default config file to $ZOOKEEPER_CONF_FILE" 1>&2
  cp $KAFKA_INSTALL_DIR/config/zookeeper.properties $ZOOKEEPER_CONF_FILE
fi

# Check the log path for zookeeper
if ! [ -d $ZOOKEEPER_LOG_DIR ]; then
  mkdir -p $ZOOKEEPER_LOG_DIR
  chown zookeeper:zookeeper -R $ZOOKEEPER_LOG_DIR
fi

# Create the zookeeper systemd service
if ! [ -f $ZOOKEEPER_SERVICE_FILE ]; then
  echo "Kafka: installing Zookeeper systemd unit..." 1>&2

  # Yes, KAFKA_HEAP_OPTS for ZOOKEEPER
  MORE_ENV=''
  if (($ENABLE_VAGRANT)); then
    MORE_ENV="Environment=KAFKA_HEAP_OPTS=-Xmx128M -Xms128M"
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
ExecStart=$KAFKA_INSTALL_DIR/bin/zookeeper-server-start.sh -daemon $ZOOKEEPER_CONF_FILE
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

# Ensure we have a kafka config setup
if ! [ -d $KAFKA_CONF_DIR ]; then
  mkdir -p $KAFKA_CONF_DIR
fi

if ! [ -f $KAFKA_CONF_FILE ]; then
  echo "Kafka: installed default config file to $KAFKA_CONF_FILE" 1>&2
  cp $KAFKA_INSTALL_DIR/config/server.properties $KAFKA_CONF_FILE
fi

# Check the log path for kafka
if ! [ -d $KAFKA_LOG_DIR ]; then
  mkdir -p $KAFKA_LOG_DIR
  chown kafka:kafka -R $KAFKA_LOG_DIR
fi

# Create the kafka systemd service
if ! [ -f $KAFKA_SERVICE_FILE ]; then
  echo "Kafka: installing Kafka systemd unit..." 1>&2

  MORE_ENV=''
  if (($ENABLE_VAGRANT)); then
    MORE_ENV="Environment=KAFKA_HEAP_OPTS=-Xmx128M -Xms128M"
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
ExecStart=$KAFKA_INSTALL_DIR/bin/kafka-server-start.sh -daemon $KAFKA_CONF_FILE
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
