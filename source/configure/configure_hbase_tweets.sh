#!/bin/bash
# Pour chaque argument -t, crée la table nommé par ce même argument dans HBase

source ./hbase_shared.sh

SCRIPT=""

while getopts ":vft:" arg; do
    case $arg in
        t)
        SCRIPT=$(printf "%screate '%s_tweets', 'place', 'feeling', 'datas'; " "$SCRIPT" "$OPTARG")
        ;;
    esac
done

$HBASE_HOME/bin/hbase shell <<< "$SCRIPT"