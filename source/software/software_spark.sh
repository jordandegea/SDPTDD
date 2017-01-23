#!/bin/bash

# Fail if any command fail
set -e

# Load the shared provisioning script
source ./deploy_shared.sh

# Load Spark install parameters
source ./spark_shared.sh

if (($FORCE_INSTALL)) || ! [ -d "$SPARK_INSTALL_DIR" ]; then
  echo "Spark: downloading..."

  get_file "$SPARK_URL" "${SPARK_FILENAME}.tgz"

  echo "Spark: installing..."

  tar xf ${SPARK_FILENAME}.tgz
  chown zeppelin:zeppelin -R $SPARK_FILENAME

  rm -rf $SPARK_INSTALL_DIR
  mv $SPARK_FILENAME $SPARK_INSTALL_DIR

  echo "Spark: succesfully installed!" >&2
else
  echo "Spark: already installed." >&2
fi
