# Zeppelin install parameters
ZEPPELIN_VERSION=0.6.2
ZEPPELIN_NAME=zeppelin-$ZEPPELIN_VERSION
ZEPPELIN_FILENAME=$ZEPPELIN_NAME-bin-all.tgz
ZEPPELIN_INSTALL_DIR="/usr/local/zeppelin"
ZEPPELIN_LOG_DIR="/usr/local/zeppelin/logs"


SERVICE_FILE="/etc/systemd/system/zeppelin.service"
START_SCRIPT="$ZEPPELIN_INSTALL_DIR/bin/zeppelin-daemon.sh start"
STOP_SCRIPT="$ZEPPELIN_INSTALL_DIR/bin/zeppelin-daemon.sh stop"
