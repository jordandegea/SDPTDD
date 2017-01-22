#!/bin/bash

# This script implements a Flink job as a system service in order to ensure HA
# of managed jobs.

# Supports SIGTERM to end the job (if supported by Flink)

_usage () {
  echo "Usage: $(basename "$BASH_SOURCE") -n service_name -- flink run arguments"
  exit 2
}

_service_status_line () {
  flink list | awk '/Running\/Restarting Jobs/{i=1;next}/-/{i=0;next}i' | \
    grep ": $JOB_NAME ("
}

_service_scheduled () {
  _service_status_line >/dev/null 2>&1
}

_service_id () {
  _service_status_line | awk '{print $4}'
}

_stop_service () {
  /usr/local/flink/bin/flink cancel $(_service_id)
}

_term () {
  echo "Caught SIGTERM, exiting!"
  EXIT_LOOP=yes
}

trap _term SIGTERM

# Parse options
while getopts ":n:" opt ; do
  case "$opt" in
    n)
      JOB_NAME="$OPTARG"
    ;;
  esac
done

# Check options
if [ -z "$JOB_NAME" ] ; then
  echo "Missing job name, cannot start" >&2
  _usage
fi

# Clear up args until --
while [[ $# -gt 0 ]]; do
    # process next argument
    case "$1" in
    --) shift; break;; # found '--', discard it and exit loop
    *) # handle unrecognized argument
    ;;
    esac
    # not '--', so discard the argument and continue
    shift
done

# Main service loop
while [ -z "$EXIT_LOOP" ]; do
  if _service_scheduled ; then
    # The service has been scheduled, just wait
    sleep 5 &
    wait
  else
    # We need to schedule the service
    if ! /usr/local/flink/bin/flink run -d "$@" ; then
      echo "Failed to schedule the service, flink run returned $?" >&2
      exit 3
    fi
  fi
done

# Stop the service on exit
if _service_scheduled ; then
  if ! _stop_service ; then
    echo "Failed to cancel the service on exit, flink cancel returned $?" >&2
  fi
fi

exit 0