#!/bin/bash

# Fail if any command fail
set -e

# Load the shared provisioning script
source ./deploy_shared.sh

# Kafka parameters
source ./kafka_shared.sh

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

  # Fix ownership
  chown root:root -R $KAFKA_NAME

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
