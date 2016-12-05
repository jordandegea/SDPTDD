#!/bin/bash

if ! [ -z "$1" ]; then
    echo "Usage: ./scripts/shutdown.sh server-name" >&2
    exit 1
fi

$(dirname "$BASH_SOURCE")/ssh.sh "$1" 'sudo shutdown -h now'
