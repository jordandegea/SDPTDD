#!/bin/bash

source ./configure_shared.sh

echo "Hello, I'm configure_test.sh!"

# Create a potentially replicated topic on the Kafka Cluster.
#
# Arguments:
# 1 =>  Hostname of the machine hosting the Zookeeper and Kafka daemons to
#       connect to;
# 2 =>  The replication factor (namely, the number of replicated versions of
#       the topic to create);
# 3 =>  The number of inner partition of each replica of the topic;
# 4 =>  The name of the topic to create.
#
# No returned value.
function create_topic {
    kafka-topics --create --zookeeper ${1}:2181\
        --replication-factor ${2} --partition ${3} --topic ${4}
}

# Parses a line of the associated configuration file containing the topics to
# create.
#
# Arguments:
# 1 =>  Path to the configuration file;
# 2 =>  Number of the line of the configuration file to parse;
# 3 =>  Name of the variable (array) to store the parsed value within.
#
# Returns:
#   An array -> 0 = Topic name;
#            -> 1 = Hostname;
#            -> 2 = Replication factor;
#            -> 3 = Number of inner partitions.
function parse_topic_config {
    line=$(sed -n "${2}p" "$1")
    eval "${3}[0]=$(echo $line | cut -d ':' -f 1)"
    eval "${3}[1]=$(echo $line | cut -d ':' -f 2)"
    eval "${3}[2]=$(echo $line | cut -d ':' -f 3)"
    eval "${3}[3]=$(echo $line | cut -d ':' -f 4)"
}

# Handling the arguments of the script.
VAGRANT_MODE=0
PATH_TO_CONF_FILE=""
while getopts ":hvf:" arg; do
    case $arg in
        h)
            echo -e "\ncreate_topic.sh - Help

This script requires one argument, namely the the path to the associated 
configuration file:

    ./create_topic.sh -f path_to_conf_file

The mentioned configuration file contains a line per topic to create, which is
built according to the following syntax:

    topic_name:hostname:replication_factor:nb_of_partitions

On top of that, if the topics should be created inside a Vagrant-virtualized
Kafka Cluster, the option \"-v\" should be specified.
    
    ./create_topic.sh -v -f path_to_conf_file
"
            exit 1
            ;;
        v)
            VAGRANT_MODE=1
            ;;
        f)
            PATH_TO_CONF_FILE="$OPTARG"
            ;;
        \?)
            echo "Unknown option: ${OPTARG}. Try \"./create_topic.sh -h\"."
            exit 1
            ;;
        :)
            echo "The option \"${OPTARG}\" needs an argument."
            echo "Try \"./create_topic.sh -h\"."
            exit 1
            ;;
    esac
done

# Checks whether the path to the configuration file has been set. Does not check
# if the configuration file exists.
if [[ -z "$PATH_TO_CONF_FILE" ]]; then
    echo "This script requires the path to the associated configuration file as
parameter. Try \"./create_topic.sh -h\"."
    exit 1
fi

# Computes the number of lines of the associated configuration file.
nb_lines=$(wc -l "$PATH_TO_CONF_FILE" | cut -d ' ' -f 1)
# Iterates over each line of the configuration file, parses it and creates the
# defined topic.
for i in $(seq 1 1 $nb_lines); do
    parse_topic_config "$PATH_TO_CONF_FILE" "$i" array
    if [[ $VAGRANT_MODE -eq 1 ]]; then  
        vagrant_create_topic "${array[1]}" "${array[2]}" "${array[3]}" "${array[0]}"
    else
        create_topic "${array[1]}" "${array[2]}" "${array[3]}" "${array[0]}"
    fi
done
