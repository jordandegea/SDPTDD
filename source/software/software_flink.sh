#!/bin/bash

# Fail if any command fail
set -e

# Load the shared provisioning script
source ./deploy_shared.sh

# Load flink setup parameters
source ./flink_shared.sh

FLINK_BASE_NAME="flink-1.1.3"

# Install Flink
if (($FORCE_INSTALL)) || ! [ -d $FLINK_INSTALL_DIR ]; then
  echo "Flink: Installing..."
  get_file "https://archive.apache.org/dist/flink/flink-1.1.3/flink-1.1.3-bin-hadoop2-scala_2.11.tgz" "$FLINK_BASE_NAME-2.11.tgz"

  # Extract archive
  tar xf "$FLINK_BASE_NAME-2.11.tgz"

  # Fix ownership
  chown root:root -R $FLINK_BASE_NAME
  
  # Install to the chosen location
  rm -rf $FLINK_INSTALL_DIR
  mv $FLINK_BASE_NAME $FLINK_INSTALL_DIR

  # Symlink all files to /usr/local/bin
  for BINARY in $FLINK_INSTALL_DIR/bin/*; do
    case "$BINARY" in
      *.bat)
        echo -n # skip Windows bat file
        ;;
      *.sh)
        echo -n # skip sh files
        ;;
      *)
        FN=/usr/local/bin/$(basename "$BINARY")
        echo "#!/bin/bash
$BINARY \"\$@\"" >"$FN"
        chmod +x "$FN"
        ;;
    esac
  done
fi

# Download dependencies
DEPENDENCIES="https://repo.maven.apache.org/maven2/aopalliance/aopalliance/1.0/aopalliance-1.0.jar
https://repo.maven.apache.org/maven2/asm/asm/3.1/asm-3.1.jar
https://repo.maven.apache.org/maven2/com/101tec/zkclient/0.3/zkclient-0.3.jar
https://repo.maven.apache.org/maven2/com/esotericsoftware/kryo/kryo/2.24.0/kryo-2.24.0.jar
https://repo.maven.apache.org/maven2/com/esotericsoftware/minlog/minlog/1.2/minlog-1.2.jar
https://repo.maven.apache.org/maven2/com/fasterxml/jackson/core/jackson-annotations/2.4.0/jackson-annotations-2.4.0.jar
https://repo.maven.apache.org/maven2/com/fasterxml/jackson/core/jackson-core/2.4.2/jackson-core-2.4.2.jar
https://repo.maven.apache.org/maven2/com/fasterxml/jackson/core/jackson-databind/2.4.2/jackson-databind-2.4.2.jar
https://repo.maven.apache.org/maven2/com/github/scopt/scopt_2.11/3.2.0/scopt_2.11-3.2.0.jar
https://repo.maven.apache.org/maven2/com/github/stephenc/findbugs/findbugs-annotations/1.3.9-1/findbugs-annotations-1.3.9-1.jar
https://repo.maven.apache.org/maven2/com/github/stephenc/high-scale-lib/high-scale-lib/1.1.1/high-scale-lib-1.1.1.jar
https://repo.maven.apache.org/maven2/com/google/code/findbugs/jsr305/1.3.9/jsr305-1.3.9.jar
https://repo.maven.apache.org/maven2/com/google/guava/guava/12.0.1/guava-12.0.1.jar
https://repo.maven.apache.org/maven2/com/google/inject/extensions/guice-servlet/3.0/guice-servlet-3.0.jar
https://repo.maven.apache.org/maven2/com/google/inject/guice/3.0/guice-3.0.jar
https://repo.maven.apache.org/maven2/com/google/protobuf/protobuf-java/2.5.0/protobuf-java-2.5.0.jar
https://repo.maven.apache.org/maven2/com/jamesmurty/utils/java-xmlbuilder/0.4/java-xmlbuilder-0.4.jar
https://repo.maven.apache.org/maven2/com/jcraft/jsch/0.1.42/jsch-0.1.42.jar
https://repo.maven.apache.org/maven2/com/sun/jersey/contribs/jersey-guice/1.9/jersey-guice-1.9.jar
https://repo.maven.apache.org/maven2/com/sun/jersey/jersey-core/1.9/jersey-core-1.9.jar
https://repo.maven.apache.org/maven2/com/sun/jersey/jersey-json/1.9/jersey-json-1.9.jar
https://repo.maven.apache.org/maven2/com/sun/jersey/jersey-server/1.9/jersey-server-1.9.jar
https://repo.maven.apache.org/maven2/com/sun/xml/bind/jaxb-impl/2.2.3-1/jaxb-impl-2.2.3-1.jar
https://repo.maven.apache.org/maven2/com/thoughtworks/paranamer/paranamer/2.3/paranamer-2.3.jar
https://repo.maven.apache.org/maven2/com/twitter/chill-java/0.7.4/chill-java-0.7.4.jar
https://repo.maven.apache.org/maven2/com/twitter/chill_2.11/0.7.4/chill_2.11-0.7.4.jar
https://repo.maven.apache.org/maven2/com/typesafe/akka/akka-actor_2.11/2.3.7/akka-actor_2.11-2.3.7.jar
https://repo.maven.apache.org/maven2/com/typesafe/akka/akka-remote_2.11/2.3.7/akka-remote_2.11-2.3.7.jar
https://repo.maven.apache.org/maven2/com/typesafe/akka/akka-slf4j_2.11/2.3.7/akka-slf4j_2.11-2.3.7.jar
https://repo.maven.apache.org/maven2/com/typesafe/config/1.2.1/config-1.2.1.jar
https://repo.maven.apache.org/maven2/com/yammer/metrics/metrics-core/2.2.0/metrics-core-2.2.0.jar
https://repo.maven.apache.org/maven2/commons-beanutils/commons-beanutils-bean-collections/1.8.3/commons-beanutils-bean-collections-1.8.3.jar
https://repo.maven.apache.org/maven2/commons-cli/commons-cli/1.3.1/commons-cli-1.3.1.jar
https://repo.maven.apache.org/maven2/commons-codec/commons-codec/1.9/commons-codec-1.9.jar
https://repo.maven.apache.org/maven2/commons-collections/commons-collections/3.2.2/commons-collections-3.2.2.jar
https://repo.maven.apache.org/maven2/commons-configuration/commons-configuration/1.7/commons-configuration-1.7.jar
https://repo.maven.apache.org/maven2/commons-daemon/commons-daemon/1.0.13/commons-daemon-1.0.13.jar
https://repo.maven.apache.org/maven2/commons-digester/commons-digester/1.8.1/commons-digester-1.8.1.jar
https://repo.maven.apache.org/maven2/commons-el/commons-el/1.0/commons-el-1.0.jar
https://repo.maven.apache.org/maven2/commons-httpclient/commons-httpclient/3.1/commons-httpclient-3.1.jar
https://repo.maven.apache.org/maven2/commons-io/commons-io/2.4/commons-io-2.4.jar
https://repo.maven.apache.org/maven2/commons-logging/commons-logging/1.2/commons-logging-1.2.jar
https://repo.maven.apache.org/maven2/commons-net/commons-net/3.1/commons-net-3.1.jar
https://repo.maven.apache.org/maven2/io/dropwizard/metrics/metrics-core/3.1.0/metrics-core-3.1.0.jar
https://repo.maven.apache.org/maven2/io/dropwizard/metrics/metrics-json/3.1.0/metrics-json-3.1.0.jar
https://repo.maven.apache.org/maven2/io/dropwizard/metrics/metrics-jvm/3.1.0/metrics-jvm-3.1.0.jar
https://repo.maven.apache.org/maven2/io/netty/netty-all/4.0.23.Final/netty-all-4.0.23.Final.jar
https://repo.maven.apache.org/maven2/io/netty/netty-all/4.0.27.Final/netty-all-4.0.27.Final.jar
https://repo.maven.apache.org/maven2/io/netty/netty/3.6.6.Final/netty-3.6.6.Final.jar
https://repo.maven.apache.org/maven2/io/netty/netty/3.7.0.Final/netty-3.7.0.Final.jar
https://repo.maven.apache.org/maven2/javax/activation/activation/1.1/activation-1.1.jar
https://repo.maven.apache.org/maven2/javax/inject/javax.inject/1/javax.inject-1.jar
https://repo.maven.apache.org/maven2/javax/servlet/servlet-api/2.5/servlet-api-2.5.jar
https://repo.maven.apache.org/maven2/javax/xml/bind/jaxb-api/2.2.2/jaxb-api-2.2.2.jar
https://repo.maven.apache.org/maven2/javax/xml/stream/stax-api/1.0-2/stax-api-1.0-2.jar
https://repo.maven.apache.org/maven2/junit/junit/4.12/junit-4.12.jar
https://repo.maven.apache.org/maven2/log4j/log4j/1.2.17/log4j-1.2.17.jar
https://repo.maven.apache.org/maven2/net/java/dev/jets3t/jets3t/0.9.0/jets3t-0.9.0.jar
https://repo.maven.apache.org/maven2/net/jpountz/lz4/lz4/1.2.0/lz4-1.2.0.jar
https://repo.maven.apache.org/maven2/org/apache/avro/avro/1.7.6/avro-1.7.6.jar
https://repo.maven.apache.org/maven2/org/apache/commons/commons-compress/1.4.1/commons-compress-1.4.1.jar
https://repo.maven.apache.org/maven2/org/apache/commons/commons-lang3/3.3.2/commons-lang3-3.3.2.jar
https://repo.maven.apache.org/maven2/org/apache/commons/commons-math/2.1/commons-math-2.1.jar
https://repo.maven.apache.org/maven2/org/apache/commons/commons-math3/3.5/commons-math3-3.5.jar
https://repo.maven.apache.org/maven2/org/apache/directory/api/api-asn1-api/1.0.0-M20/api-asn1-api-1.0.0-M20.jar
https://repo.maven.apache.org/maven2/org/apache/directory/api/api-util/1.0.0-M20/api-util-1.0.0-M20.jar
https://repo.maven.apache.org/maven2/org/apache/directory/server/apacheds-i18n/2.0.0-M15/apacheds-i18n-2.0.0-M15.jar
https://repo.maven.apache.org/maven2/org/apache/directory/server/apacheds-kerberos-codec/2.0.0-M15/apacheds-kerberos-codec-2.0.0-M15.jar
https://repo.maven.apache.org/maven2/org/apache/flink/flink-annotations/1.1.3/flink-annotations-1.1.3.jar
https://repo.maven.apache.org/maven2/org/apache/flink/flink-clients_2.11/1.1.3/flink-clients_2.11-1.1.3.jar
https://repo.maven.apache.org/maven2/org/apache/flink/flink-connector-kafka-0.8_2.11/1.1.3/flink-connector-kafka-0.8_2.11-1.1.3.jar
https://repo.maven.apache.org/maven2/org/apache/flink/flink-connector-kafka-base_2.11/1.1.3/flink-connector-kafka-base_2.11-1.1.3.jar
https://repo.maven.apache.org/maven2/org/apache/flink/flink-connector-twitter_2.11/1.1.3/flink-connector-twitter_2.11-1.1.3.jar
https://repo.maven.apache.org/maven2/org/apache/flink/flink-core/1.1.3/flink-core-1.1.3.jar
https://repo.maven.apache.org/maven2/org/apache/flink/flink-hbase_2.11/1.1.3/flink-hbase_2.11-1.1.3.jar
https://repo.maven.apache.org/maven2/org/apache/flink/flink-java/1.1.3/flink-java-1.1.3.jar
https://repo.maven.apache.org/maven2/org/apache/flink/flink-metrics-core/1.1.3/flink-metrics-core-1.1.3.jar
https://repo.maven.apache.org/maven2/org/apache/flink/flink-optimizer_2.11/1.1.3/flink-optimizer_2.11-1.1.3.jar
https://repo.maven.apache.org/maven2/org/apache/flink/flink-runtime_2.11/1.1.3/flink-runtime_2.11-1.1.3.jar
https://repo.maven.apache.org/maven2/org/apache/flink/flink-shaded-hadoop2/1.1.3/flink-shaded-hadoop2-1.1.3.jar
https://repo.maven.apache.org/maven2/org/apache/flink/flink-streaming-java_2.11/1.1.3/flink-streaming-java_2.11-1.1.3.jar
https://repo.maven.apache.org/maven2/org/apache/flink/force-shading/1.1.3/force-shading-1.1.3.jar
https://repo.maven.apache.org/maven2/org/apache/hadoop/hadoop-annotations/2.5.1/hadoop-annotations-2.5.1.jar
https://repo.maven.apache.org/maven2/org/apache/hadoop/hadoop-auth/2.5.1/hadoop-auth-2.5.1.jar
https://repo.maven.apache.org/maven2/org/apache/hadoop/hadoop-common/2.5.1/hadoop-common-2.5.1.jar
https://repo.maven.apache.org/maven2/org/apache/hadoop/hadoop-mapreduce-client-core/2.5.1/hadoop-mapreduce-client-core-2.5.1.jar
https://repo.maven.apache.org/maven2/org/apache/hadoop/hadoop-yarn-api/2.5.1/hadoop-yarn-api-2.5.1.jar
https://repo.maven.apache.org/maven2/org/apache/hadoop/hadoop-yarn-common/2.5.1/hadoop-yarn-common-2.5.1.jar
https://repo.maven.apache.org/maven2/org/apache/hbase/hbase-annotations/1.0.3/hbase-annotations-1.0.3.jar
https://repo.maven.apache.org/maven2/org/apache/hbase/hbase-client/1.0.3/hbase-client-1.0.3.jar
https://repo.maven.apache.org/maven2/org/apache/hbase/hbase-common/0.98.11-hadoop2/hbase-common-0.98.11-hadoop2-tests.jar
https://repo.maven.apache.org/maven2/org/apache/hbase/hbase-common/1.0.3/hbase-common-1.0.3.jar
https://repo.maven.apache.org/maven2/org/apache/hbase/hbase-hadoop-compat/0.98.11-hadoop2/hbase-hadoop-compat-0.98.11-hadoop2.jar
https://repo.maven.apache.org/maven2/org/apache/hbase/hbase-hadoop2-compat/0.98.11-hadoop2/hbase-hadoop2-compat-0.98.11-hadoop2.jar
https://repo.maven.apache.org/maven2/org/apache/hbase/hbase-prefix-tree/0.98.11-hadoop2/hbase-prefix-tree-0.98.11-hadoop2.jar
https://repo.maven.apache.org/maven2/org/apache/hbase/hbase-protocol/1.0.3/hbase-protocol-1.0.3.jar
https://repo.maven.apache.org/maven2/org/apache/hbase/hbase-server/0.98.11-hadoop2/hbase-server-0.98.11-hadoop2.jar
https://repo.maven.apache.org/maven2/org/apache/htrace/htrace-core/3.1.0-incubating/htrace-core-3.1.0-incubating.jar
https://repo.maven.apache.org/maven2/org/apache/httpcomponents/httpclient/4.2.5/httpclient-4.2.5.jar
https://repo.maven.apache.org/maven2/org/apache/httpcomponents/httpcore/4.1.2/httpcore-4.1.2.jar
https://repo.maven.apache.org/maven2/org/apache/kafka/kafka-clients/0.8.2.2/kafka-clients-0.8.2.2.jar
https://repo.maven.apache.org/maven2/org/apache/kafka/kafka_2.11/0.8.2.2/kafka_2.11-0.8.2.2.jar
https://repo.maven.apache.org/maven2/org/apache/sling/org.apache.sling.commons.json/2.0.6/org.apache.sling.commons.json-2.0.6.jar
https://repo.maven.apache.org/maven2/org/apache/zookeeper/zookeeper/3.4.6/zookeeper-3.4.6.jar
https://repo.maven.apache.org/maven2/org/clapper/grizzled-slf4j_2.11/1.0.2/grizzled-slf4j_2.11-1.0.2.jar
https://repo.maven.apache.org/maven2/org/cloudera/htrace/htrace-core/2.04/htrace-core-2.04.jar
https://repo.maven.apache.org/maven2/org/codehaus/jackson/jackson-core-asl/1.8.8/jackson-core-asl-1.8.8.jar
https://repo.maven.apache.org/maven2/org/codehaus/jackson/jackson-jaxrs/1.8.8/jackson-jaxrs-1.8.8.jar
https://repo.maven.apache.org/maven2/org/codehaus/jackson/jackson-mapper-asl/1.8.8/jackson-mapper-asl-1.8.8.jar
https://repo.maven.apache.org/maven2/org/codehaus/jackson/jackson-xc/1.8.3/jackson-xc-1.8.3.jar
https://repo.maven.apache.org/maven2/org/codehaus/jettison/jettison/1.1/jettison-1.1.jar
https://repo.maven.apache.org/maven2/org/hamcrest/hamcrest-core/1.3/hamcrest-core-1.3.jar
https://repo.maven.apache.org/maven2/org/jamon/jamon-runtime/2.3.1/jamon-runtime-2.3.1.jar
https://repo.maven.apache.org/maven2/org/javassist/javassist/3.18.2-GA/javassist-3.18.2-GA.jar
https://repo.maven.apache.org/maven2/org/jruby/jcodings/jcodings/1.0.8/jcodings-1.0.8.jar
https://repo.maven.apache.org/maven2/org/jruby/joni/joni/2.1.2/joni-2.1.2.jar
https://repo.maven.apache.org/maven2/org/mortbay/jetty/jetty-util/6.1.26/jetty-util-6.1.26.jar
https://repo.maven.apache.org/maven2/org/mortbay/jetty/jetty/6.1.26/jetty-6.1.26.jar
https://repo.maven.apache.org/maven2/org/objenesis/objenesis/2.1/objenesis-2.1.jar
https://repo.maven.apache.org/maven2/org/scala-lang/modules/scala-parser-combinators_2.11/1.0.2/scala-parser-combinators_2.11-1.0.2.jar
https://repo.maven.apache.org/maven2/org/scala-lang/modules/scala-xml_2.11/1.0.2/scala-xml_2.11-1.0.2.jar
https://repo.maven.apache.org/maven2/org/scala-lang/scala-library/2.11.7/scala-library-2.11.7.jar
https://repo.maven.apache.org/maven2/org/slf4j/slf4j-api/1.7.7/slf4j-api-1.7.7.jar
https://repo.maven.apache.org/maven2/org/slf4j/slf4j-log4j12/1.7.7/slf4j-log4j12-1.7.7.jar
https://repo.maven.apache.org/maven2/org/tukaani/xz/1.0/xz-1.0.jar
https://repo.maven.apache.org/maven2/org/uncommons/maths/uncommons-maths/1.2.2a/uncommons-maths-1.2.2a.jar
https://repo.maven.apache.org/maven2/org/xerial/snappy/snappy-java/1.1.1.7/snappy-java-1.1.1.7.jar
https://repo.maven.apache.org/maven2/tomcat/jasper-compiler/5.5.23/jasper-compiler-5.5.23.jar
https://repo.maven.apache.org/maven2/tomcat/jasper-runtime/5.5.23/jasper-runtime-5.5.23.jar
https://repo.maven.apache.org/maven2/xmlenc/xmlenc/0.52/xmlenc-0.52.jar"

cd $FLINK_INSTALL_DIR/lib

mv flink-dist_2.11-1.1.3.jar /tmp/
mv flink-python_2.11-1.1.3.jar /tmp/
mv log4j-1.2.17.jar /tmp/
mv slf4j-log4j12-1.7.7.jar /tmp/

rm -rf *.jar

for DEP in $DEPENDENCIES; do
  echo "Downloading $DEP..."
  wget -N -q $DEP
done

mv /tmp/flink-dist_2.11-1.1.3.jar .
mv /tmp/flink-python_2.11-1.1.3.jar .
mv /tmp/log4j-1.2.17.jar .
mv /tmp/slf4j-log4j12-1.7.7.jar .