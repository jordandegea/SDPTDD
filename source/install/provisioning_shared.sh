# Shared functions for provisioning scripts
# This script is meant to be sourced, not executed directly
# Hence the missing shebang

# Scripts sourcing this script must be run as root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# Detect the environment
ENABLE_VAGRANT=0
FORCE_INSTALL=0
while getopts ":vf" opt; do
  case $opt in
    v)
      echo "Running in vagrant mode." >&2
      ENABLE_VAGRANT=1
      ;;
    f)
      echo "Running in force mode." >&2
      FORCE_INSTALL=1
      ;;
  esac
done

# Detect what is the temporary directory
RESOURCES_DIRECTORY='/tmp'
if (($ENABLE_VAGRANT)); then
  RESOURCES_DIRECTORY='/vagrant/resources'
fi
