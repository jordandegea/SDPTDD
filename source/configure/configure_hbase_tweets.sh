#!/bin/bash

source ./deploy_shared.sh

while getopts ":vft:" arg; do
    case $arg in
        t)
        echo "create '${OPTARG}_tweets', 'feeling', 'datas'" | ./bin/hbase shell
        ;;
    esac
done
