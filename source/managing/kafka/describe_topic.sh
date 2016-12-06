#! /bin/bash

################################################################################
# Bash script - describe_topic.sh
# Prints a description of the current hosted topics of a Kafka Cluster.
################################################################################

# Handling the arguments of the script.
VAGRANT_MODE=0
HOST_NAME=""
while getopts ":hvn:" arg; do
    case $arg in
        h)
            echo -e "\ndescribe_topic.sh - Help

This script requires one argument, namely the hostname of the Zookeeper/Kafka²
server to ask for a description of the hosted topics:

    ./describe_topic.sh -n hostname

On top of that, if the asked server is running inside a Vagrant-virtualized
Kafka Cluster, the option \"-v\" should be specified.
    
    ./describe_topic.sh -v -n hostname
"
            exit 1
            ;;
        v)
            VAGRANT_MODE=1
            ;;
        n)
            HOST_NAME="$OPTARG"
            ;;
        \?)
            echo "Unknown option: ${OPTARG}. Try \"./describe_topic.sh -h\"."
            exit 1
            ;;
        :)
            echo "The option \"${OPTARG}\" needs an argument."
            echo "Try \"./describe_topic.sh -h\"."
            exit 1
            ;;
    esac
done

# Checks whether the hostname has been set.
if [[ -z "$HOST_NAME" ]]; then
    echo "This script requires the hostname of the Zookeeper/Kafka server to
ask for a description. Try \"./describe_topic.sh -h\"."
    exit 1
fi

# Asks the specified Zookeeper/Kafka server for a description of the current
# hosted topics.
if [[ $VAGRANT_MODE -eq 1 ]]; then
    vagrant ssh "$HOST_NAME" -c "kafka-topics --describe --zookeeper ${HOST_NAME}:2181"
else
    ssh "$HOST_NAME" "kafka-topics --describe --zookeeper ${HOST_NAME}:2181"
fi
