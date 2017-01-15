#!/bin/bash
# Pour chaque argument -t, crée la table nommé par ce même argument dans HBase

source ./hbase_shared.sh

while getopts ":vft:" arg; do
    case $arg in
        t)
        echo "create '${OPTARG}_tweets', 'feeling', 'datas'" | $HBASE_HOME/bin/hbase shell
        ;;
    esac
done
