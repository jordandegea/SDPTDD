#!/bin/bash

# Fail if any command fail
set -e

# Load the shared provisioning script
source ./deploy_shared.sh

# Load Zeppelin install parameters
source ./zeppelin_shared.sh

if (($FORCE_INSTALL)) || ! [ -d $ZEPPELIN_INSTALL_DIR ]; then
  # Download Zeppelin
  echo "Zeppelin: downloading..."

  get_file "http://apache.mindstudios.com/zeppelin/$ZEPPELIN_NAME/$ZEPPELIN_FILENAME" $ZEPPELIN_FILENAME

  #Install in the right location
  echo "Zeppelin: Installing..."

  mv $ZEPPELIN_FILENAME /usr/local
  cd /usr/local/

  # Extract archive
  tar xf $ZEPPELIN_FILENAME

  # Fix ownership
  chown root:root -R $ZEPPELIN_NAME-bin-all
  
  # Install to the chosen location
  rm $ZEPPELIN_FILENAME
  rm -rf $ZEPPELIN_INSTALL_DIR
  mv $ZEPPELIN_NAME-bin-all $ZEPPELIN_INSTALL_DIR

  echo "Zeppelin: successfully installed!" 1>&2
else
  echo "Zeppelin: already installed." 1>&2
fi
