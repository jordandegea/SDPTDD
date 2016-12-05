#!/bin/bash

exit_usage () {
	echo "Usage: ./scripts/ssh.sh server-name [command-to-execute]" 1>&2
	exit
}

# Get the wanted host from first arg
SERVER_NAME=$1 ; shift
INPUT_COMMANDS="$1" ; shift

# Check command line args
if [ -z "$SERVER_NAME" ]; then
	exit_usage
fi

if ! [ -z "$@" ]; then
	exit_usage
fi

# Create the SSH command
SSH_CMD=$(grep "^${SERVER_NAME}:" hosts.txt | awk -F':' '$0 !~ /^#/ {print "ssh -i " $4 " " $2 "@" $3}')

# Check we have a valid SSH command
if [ -z "$SSH_CMD" ]; then
	echo "$SERVER_NAME: no such host." 1>&2
	exit 1
fi

if ! [ -z "$INPUT_COMMANDS" ]; then
	echo "$INPUT_COMMANDS" | $SSH_CMD 'bash -s'
else
	$SSH_CMD
fi
