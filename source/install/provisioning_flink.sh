#!/bin/bash

# Fail if any command fail
set -eo pipefail

# Load the shared provisioning script
if [ -f './provisioning_shared.sh' ]; then
  source ./provisioning_shared.sh
else
  source /vagrant/provisioning_shared.sh
fi

# So we dont need to pass in i to the scripts
NODE_NUMBER=`hostname | tr -d a-z\-`


function downloadFile {
    filename="flink-1.0.3-bin-hadoop27-scala_2.10.tgz"

    echo "Flink: downloading..."

    get_file "http://www-eu.apache.org/dist/flink/flink-1.0.3/$filename" $filename

    TARBALL=$filename
}




while getopts t:r: option; do
    case $option in
        t) TOTAL_NODES=$OPTARG;;
    esac
done


function installFlink {

    downloadFile  $filename

    tar -oxzf $TARBALL -C /opt

    }

function configureFlink {
    echo "Configuring Flink"
#set the jobmanager.rpc.address key in conf/flink-conf.yaml to master's IP (worker1)
    sed -i 's/jobmanager.rpc.address.*/jobmanager.rpc.address:10.20.1.100/' /opt/flink-1.0.3/conf/flink-conf.yaml 

     rm /opt/flink-1.0.3/conf/slaves

#Add the  hostnames of all worker nodes
   
       echo "worker2" >> /opt/flink-1.0.3/conf/slaves
       echo "worker3" >> /opt/flink-1.0.3/conf/slaves

   




}



echo "Setting up Flink"
installFlink
configureFlink
