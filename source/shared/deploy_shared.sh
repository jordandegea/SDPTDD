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
PARSED_ARGUMENTS=1
while getopts ":vf" opt; do
  case $opt in
    v)
      # echo "Running in vagrant mode." >&2
      ENABLE_VAGRANT=1
      let "PARSED_ARGUMENTS = PARSED_ARGUMENTS + 1"
      ;;
    f)
      # echo "Running in force mode." >&2
      FORCE_INSTALL=1
      let "PARSED_ARGUMENTS = PARSED_ARGUMENTS + 1"
      ;;
  esac
done

# Setting $OPTIND to the number of parsed arguments, in order to chaine
# consecutive calls to getopts without duplicating the handling of the
# arguments.
OPTIND="$PARSED_ARGUMENTS"

# Detect what is the temporary directory
RESOURCES_DIRECTORY='/tmp'
if (($ENABLE_VAGRANT)); then
  RESOURCES_DIRECTORY="/vagrant/resources/$(hostname)"
  mkdir -p $RESOURCES_DIRECTORY
fi

# Tools

# Usage: get_file http://file-to-download output-file-name.tar.gz
# Downloads (or use cached version) of given file.
get_file () {
  url=$1 ; shift
  filename=$1 ; shift

  # Download file if needed
  if ! [ -f "$RESOURCES_DIRECTORY/$filename" ]; then
    echo "Downloading $url, this may take a while..."
    wget -q -O "$RESOURCES_DIRECTORY/$filename" "$url"
  fi

  # Copy the cached file to the desired location (ie. pwd)
  cp "$RESOURCES_DIRECTORY/$filename" "$filename"
}
