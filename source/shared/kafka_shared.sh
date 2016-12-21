# Kafka installation parameters
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