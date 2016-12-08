#!/bin/bash

# Fail if any command fail
set -eo pipefail

# Load the shared provisioning script
if [ -f './provisioning_shared.sh' ]; then
  source ./provisioning_shared.sh
else
  source /vagrant/provisioning_shared.sh
fi

# Parsing the ID, specified as an argument, of the Zookeeper/Kafka
# daemons inside the Kafka Cluster.
SERVER_ID=$(hostname | tr -d 'a-z\-')
QUORUM_SPEC=""
ZOOKEEPER_CONNECT=""
while getopts ":H:" opt; do
  case "$opt" in
    H)
      while IFS='@' read -ra ADDR; do
        SRV_HOSTNAME="${ADDR[0]}"
        SRV_ADDRESS="${ADDR[1]}"
        SRV_ID=$(echo "$SRV_HOSTNAME" | tr -d 'a-z\-')

        QUORUM_SPEC=$(printf "%s\nserver.%d=%s:2888:3888" "$QUORUM_SPEC" "$SRV_ID" "$SRV_HOSTNAME")
        ZOOKEEPER_CONNECT=$(printf "%s,%s:2181" "$ZOOKEEPER_CONNECT" "$SRV_HOSTNAME")
      done <<< "$OPTARG"
      ;;
    :)
      echo "Missing argument: the option $opt needs an \
          argument." >&2
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done

# Strip leading "," from ZOOKEEPER_CONNECT
ZOOKEEPER_CONNECT=$(echo "$ZOOKEEPER_CONNECT" | tail -c +2)

# Checking that the ID of each Kafka server has been uniquely defined.
if [[ $SERVER_ID -eq 0 ]]; then
  COLOR_BLUE='\033[1;34m'
  COLOR_END='\033[0m'
  echo -e "${COLOR_BLUE}[WARNING]${COLOR_END} A unique positive ID \
should be precised thanks to the option '-i'."
fi

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

# Configuration parameters.
ZOOKEEPER_CONFIG_FILE="${KAFKA_INSTALL_DIR}/config/zookeeper.properties"
ZOOKEEPER_DATA_DIR="/tmp/zookeeper"
ZOOKEEPER_ID_FILE="${ZOOKEEPER_DATA_DIR}/myid"

KAFKA_CONFIG_FILE="${KAFKA_INSTALL_DIR}/config/server.properties"

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

# Check, and create if necessary, the data path for Zookeeper.
if [[ ! -d "$ZOOKEEPER_DATA_DIR" ]]; then
  mkdir -p "$ZOOKEEPER_DATA_DIR"
  chown zookeeper:zookeeper -R "$ZOOKEEPER_DATA_DIR"
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
ExecStart=$KAFKA_INSTALL_DIR/bin/zookeeper-server-start.sh -daemon $ZOOKEEPER_CONFIG_FILE
ExecStop=$KAFKA_INSTALL_DIR/bin/zookeeper-server-stop.sh $ZOOKEEPER_CONFIG_FILE
Restart=on-failure
SyslogIdentifier=zookeeper

[Install]
WantedBy=multi-user.target" >$ZOOKEEPER_SERVICE_FILE
else
  echo "Kafka: Zookeeper systemd unit already installed." 1>&2
fi

# Modifying the Zookeeper configuration file

# Remove previous Zookeeper Quorum config
sed -i '/# BEGIN ZOOKEEPER QUORUM CONFIG/,/# END ZOOKEEPER QUORUM CONFIG/d' "$ZOOKEEPER_CONFIG_FILE"

# Appending the configuration related to the Zookeeper Quorum.
echo "# BEGIN ZOOKEEPER QUORUM CONFIG
$QUORUM_SPEC

tickTime=2000
initLimit=10
syncLimit=5
# END ZOOKEEPER QUORUM CONFIG" >> "$ZOOKEEPER_CONFIG_FILE"

# Each member of the Zookeeper Quorum is deployed on one exclusive node of the
# cluster. As a result, it is necessary to give an ID to each member.
# This is done thanks to an extra configuration file.
echo "$SERVER_ID" > "$ZOOKEEPER_ID_FILE"

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
ExecStart=$KAFKA_INSTALL_DIR/bin/kafka-server-start.sh -daemon $KAFKA_CONFIG_FILE
ExecStop=$KAFKA_INSTALL_DIR/bin/kafka-server-stop.sh $KAFKA_CONFIG_FILE
Restart=on-failure
SyslogIdentifier=kafka

[Install]
WantedBy=multi-user.target" >$KAFKA_SERVICE_FILE
else
  echo "Kafka: Kafka systemd unit already installed." 1>&2
fi

# Modifying the Kafka configuration file, taking into account the 
# specifics of each broker.

# Setting the broker ID.
sed -i "s/broker.id=[0-9]*/broker.id=$SERVER_ID/" $KAFKA_CONFIG_FILE
# Enabling topic deletion.
sed -i "s/^#delete/delete/" $KAFKA_CONFIG_FILE
# Setting the configuration related to the connection to the TCP socket used
# to communicate inside the cluster.
sed -i "s/^#*listeners=.*9092/\
listeners=PLAINTEXT:\\/\\/$(hostname):9092/" $KAFKA_CONFIG_FILE
# Setting the connection information to the Zookeeper Quorum.
sed -i "s/zookeeper.connect=.*/zookeeper.connect\
=$ZOOKEEPER_CONNECT/" $KAFKA_CONFIG_FILE

# Vagrant tends to slow down the network, it is compulsory to increase the
# timeout delay.
if (($ENABLE_VAGRANT)); then
  sed -i "s/zookeeper.connection.timeout.ms=[0-9]*/\
zookeeper.connection.timeout.ms=120000/" $KAFKA_CONFIG_FILE
fi

# Reload unit files
systemctl daemon-reload


# Due to a "Linux /etc/hosts" bug with distributed systems, it is necessary
# to remove the "127.0.0.1<->workerX" definition from the "/etc/hosts" file.
tail -n +2 /etc/hosts > tmp
cat tmp > /etc/hosts
rm -f tmp
