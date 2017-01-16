#!/bin/bash

# Fail if any command fail
set -e

# Load the shared provisioning script
source ./deploy_shared.sh

# BookKeeper parameters
source ./bookkeeper_shared.sh

if (($FORCE_INSTALL)) || ! [ -d $BOOKKEEPER_HOME ]; then
  # Download Kafka
  echo "BookKeeper: downloading..." 1>&2

  get_file "$BOOKKEEPER_DOWNLOAD" $BOOKKEEPER_FILENAME

  # Extract archive
  echo "BookKeeper: installing..." 1>&2
  tar xf $BOOKKEEPER_FILENAME

  # Fix ownership
  chown root:root -R $BOOKKEEPER_DIR

  # Install to the chosen location
  rm -rf $BOOKKEEPER_HOME
  mv $BOOKKEEPER_DIR $BOOKKEEPER_HOME

  # Symlink all files to /usr/local/bin
  for BINARY in $BOOKKEEPER_HOME/bin/*; do
    case "$BINARY" in
      *.sh)
        echo -n # skip .sh
        ;;
      *)
        FN=/usr/local/bin/$(basename "$BINARY")
        echo "#!/bin/bash
$BINARY \"\$@\"" >"$FN"
        chmod +x "$FN"
        ;;
    esac
  done

  # Cleanup
  rm -f $BOOKKEEPER_FILENAME
else
  echo "BookKeeper: already installed." 1>&2
fi
