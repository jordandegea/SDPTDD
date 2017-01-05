#!/bin/bash
# Pour chaque argument -t, crée la table nommé par ce même argument dans HBase

source ./deploy_shared.sh

while getopts ":vft:" arg; do
    case $arg in
        t)
        echo "create '${OPTARG}_tweets', 'feeling', 'datas'" | ./bin/hbase shell
        ;;
    esac
done
