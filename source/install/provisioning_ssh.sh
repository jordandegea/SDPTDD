#!/bin/bash

NODES=$1

pushd .
cd ~/.ssh
rm -f ~/.ssh/id_rsa*
ssh-keygen -q -t rsa -P "" -f /home/vagrant/.ssh/id_rsa
eval `ssh-agent -s`
eval "$(ssh-agent)"
ssh-add -L
ssh-add
ssh-add -L

echo "ssh-copy-id start"
for i in $(seq 1 $NODES);do
	sshpass -pvagrant ssh-copy-id -o StrictHostKeyChecking=no -i /home/vagrant/.ssh/id_rsa.pub vagrant@10.20.1.1$(printf %02d $i)
done
echo "ssh-copy-id end"

popd
