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

# Check the log path for flink
mkdir -p $FLINK_LOG_DIR
chown flink:flink -R $FLINK_LOG_DIR

# Check the pid path for flink
mkdir -p $FLINK_PID_DIR
chown flink:flink -R $FLINK_PID_DIR

# tmpfiles.d
echo "# Flink service folders
d  $FLINK_LOG_DIR 0755 flink flink - -
d  $FLINK_PID_DIR 0755 flink flink - -
" >/etc/tmpfiles.d/flink.conf

# Log to systemd
echo "log4j.rootLogger=INFO, stdout

# Log all infos in the given stdout
log4j.appender.stdout=org.apache.log4j.ConsoleAppender
log4j.appender.stdout.layout=org.apache.log4j.PatternLayout
log4j.appender.stdout.layout.ConversionPattern=%d{yyyy-MM-dd HH:mm:ss,SSS} %-5p %-60c %x - %m%n

# suppress the irrelevant (wrong) warnings from the netty channel handler
log4j.logger.org.jboss.netty.channel.DefaultChannelPipeline=ERROR, stdout
" >$FLINK_INSTALL_DIR/conf/log4j.properties
cp $FLINK_INSTALL_DIR/conf/log4j.properties $FLINK_INSTALL_DIR/conf/log4j-cli.properties
cp $FLINK_INSTALL_DIR/conf/log4j.properties $FLINK_INSTALL_DIR/conf/log4j-yarn-session.properties

echo "<configuration>
    <appender name=\"STDOUT\" class=\"ch.qos.logback.core.ConsoleAppender\">
        <encoder>
            <pattern>%d{yyyy-MM-dd HH:mm:ss.SSS} [%thread] %-5level %logger{60} %X{sourceThread} - %msg%n</pattern>
        </encoder>
    </appender>

    <root level=\"INFO\">
        <appender-ref ref=\"STDOUT\"/>
    </root>
</configuration>
" >$FLINK_INSTALL_DIR/conf/logback.xml
cp $FLINK_INSTALL_DIR/conf/logback.xml $FLINK_INSTALL_DIR/conf/logback-yarn.xml

# Patch the daemon startup script (Apache doesn't know anything about daemons)
sed -i 's/ > "$out"//' $FLINK_INSTALL_DIR/bin/flink-daemon.sh

# Create systemd unit for flink service
echo "Flink: installing Flink systemd unit..." 1>&2

echo "jobmanager.rpc.address: jobmanager_replace_me
jobmanager.rpc.port: 6123
taskmanager.numberOfTaskSlots: 20
taskmanager.memory.preallocate: false
parallelism.default: 2
jobmanager.web.port: 8081
env.log.dir: $FLINK_LOG_DIR
env.pid.dir: $FLINK_PID_DIR
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
ExecStart=/bin/bash $FLINK_INSTALL_DIR/bin/%i.sh start cluster
ExecStop=/bin/bash $FLINK_INSTALL_DIR/bin/%i.sh stop
PIDFile=$FLINK_PID_DIR/flink-flink-%i.pid
Restart=on-failure
SyslogIdentifier=flink@%i

[Install]
WantedBy=multi-user.target" >$FLINK_SERVICE_FILE

# Create systemd unit for flink service
cp files/flink_service.sh /usr/local/bin
chmod 0755 /usr/local/bin/flink_service.sh
chown root:root /usr/local/bin/flink_service.sh

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
ExecStart=/usr/local/bin/flink_service.sh -n 'Flink consumer %i' -- $FLINK_INSTALL_DIR/KafkaHbaseBridge.jar --port 9000 --topic %i --bootstrap.servers $FLINK_BOOTSTRAP --zookeeper.connect localhost:2181 --group.id %iconsumer --hbasetable %i_tweets --hbasequorum $HBASE_QUORUM --hbaseport 2181
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
ExecStart=/usr/local/bin/flink_service.sh -n 'Flink console consumer %i' -- $FLINK_INSTALL_DIR/KafkaConsoleBridge.jar --port 9000 --topic %i --bootstrap.servers $FLINK_BOOTSTRAP --zookeeper.connect localhost:2181 --group.id %iconsumer --hbasetable %i_tweets --hbasequorum $HBASE_QUORUM --hbaseport 2181
SyslogIdentifier=flink_city_console@%i

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
WorkingDirectory=$FLINK_INSTALL_DIR
ExecStart=/usr/local/bin/flink_service.sh -n 'Twitter Fake Producer' -- $FLINK_INSTALL_DIR/FakeTwitterProducer.jar 1 $FLINK_BOOTSTRAP
SyslogIdentifier=flink_producer_fake

[Install]
WantedBy=multi-user.target" >/etc/systemd/system/flink_producer_fake.service

echo "Flink: installing Flink Twitter producer systemd unit..." 1>&2

echo "[Unit]
Description=Flink Twitter producer
Requires=network.target
After=network.target

[Service]
User=flink
Group=flink
WorkingDirectory=$FLINK_INSTALL_DIR
ExecStart=/usr/local/bin/flink_service.sh -n 'Twitter Producer' -- $FLINK_INSTALL_DIR/TwitterProducer.jar $FLINK_BOOTSTRAP
SyslogIdentifier=flink_producer

[Install]
WantedBy=multi-user.target" >/etc/systemd/system/flink_producer.service

systemctl daemon-reload
