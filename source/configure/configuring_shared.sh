# Shared utilites for configuration scripts

echo "Hello, I'm the shared configure script"

# Detect the environment
ENABLE_VAGRANT=0
PARSED_ARGUMENTS=1
while getopts ":v" opt; do
  case $opt in
    v)
      echo "Running in vagrant mode." >&2
      ENABLE_VAGRANT=1
      let "PARSED_ARGUMENTS = PARSED_ARGUMENTS + 1"
      ;;
  esac
done

# Setting $OPTIND to the number of parsed arguments, in order to chaine
# consecutive calls to getopts without duplicating the handling of the
# arguments.
OPTIND="$PARSED_ARGUMENTS"

