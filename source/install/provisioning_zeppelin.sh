#!/bin/bash

# Fail if any command fail
set -eo pipefail

# Load the shared provisioning script
if [ -f './provisioning_shared.sh' ]; then
  source ./provisioning_shared.sh
else
  source /vagrant/provisioning_shared.sh
fi

ZEPPELIN_VERSION=0.6.2
ZEPPELIN_NAME=zeppelin-$ZEPPELIN_VERSION
ZEPPELIN_FILENAME=$ZEPPELIN_NAME-bin-all.tgz
ZEPPELIN_INSTALL_DIR=/usr/local/zeppelin
MAVEN_NAME=apache-maven-3.3.9
MAVEN_FILENAME=$MAVEN_NAME-bin.tar.gz

if(($FORCE_INSTALL)) || ! [ -d $ZEPPELIN_INSTALL_DIR ]; then
	# Download file if needed
	if ! [ -f "/vagrant/resources/$ZEPPELIN_FILENAME" ]; then
		echo "Zeppelin: Downloading, this may take a while..."
		wget -q -O "/vagrant/resources/$ZEPPELIN_FILENAME" "http://apache.mindstudios.com/zeppelin/$ZEPPELIN_NAME/$ZEPPELIN_FILENAME" 
	fi

	#Install in the right location
	echo "Zeppelin: Installing..."
	cd /usr/local/
	cp "/vagrant/resources/$ZEPPELIN_FILENAME" $ZEPPELIN_FILENAME
	tar xf $ZEPPELIN_FILENAME
	rm $ZEPPELIN_FILENAME
	rm -rf $ZEPPELIN_INSTALL_DIR
	mv $ZEPPELIN_NAME-bin-all $ZEPPELIN_INSTALL_DIR


	#INSTRUCTIONS FOR BUILD BUT BUILD NOT WORKING / STILL GOOD TO KEEP UNDER THE ELBOW

	#Additionnal softwares and libs needed
	# echo "Zeppelin: Installing git..."
	# apt-get -qq install -y git

	# echo "Zeppelin: Installing npm..."
	# apt-get -qq install -y npm

	# echo "Zeppelin: Installing libfontconfig..."
	# apt-get -qq install -y libfontconfig


	# echo "Zeppelin: Installing maven for build..."
	# if ! [ -f "/vagrant/resources/$MAVEN_FILENAME" ]; then
	# 	wget -q -O "/vagrant/resources/$MAVEN_FILENAME" "apache.mediamirrors.org/maven/maven-3/3.3.9/binaries/$MAVEN_FILENAME"
	# fi
	# tar -zxf "/vagrant/resources/$MAVEN_FILENAME" -C "/usr/local/"
	# if ! [ -f "/usr/local/bin/mvn" ]; then
	# 	ln -s "/usr/local/$MAVEN_NAME/bin/mvn" "/usr/local/bin/mvn"
	# fi

	# echo "Zeppelin: Building..."
	# cd $ZEPPELIN_INSTALL_DIR
	# mvn clean package -DskipTests -Phadoop-2.6 -Dhadoop.version=2.6.0 -P build-distr -Dhbase.hbase.version=1.2.0 -Dhbase.hadoop.version=2.6.0


  echo "Zeppelin: successfully installed!" 1>&2

else
  echo "Zeppelin: already installed." 1>&2
fi
