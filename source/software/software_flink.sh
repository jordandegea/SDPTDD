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
  get_file "https://archive.apache.org/dist/flink/flink-1.1.3/flink-1.1.3-bin-hadoop2-scala_2.11.tgz" "$FLINK_BASE_NAME.tgz"

  # Extract archive
  tar xf "$FLINK_BASE_NAME.tgz"

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
