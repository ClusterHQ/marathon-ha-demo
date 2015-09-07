#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
set -e

echo "Launching vagrant cluster"
vagrant up

unixsecs=$(date +%s)

echo "getting public IP addresses for cluster"
MASTER_PUBLIC=$(vagrant awsinfo -m master -p | grep public_ip | cut -d '"' -f4)
NODE1_PUBLIC=$(vagrant awsinfo -m node1 -p | grep public_ip | cut -d '"' -f4)
NODE2_PUBLIC=$(vagrant awsinfo -m node2 -p | grep public_ip | cut -d '"' -f4)
echo "getting private IP addresses for cluster"
MASTER_PRIVATE=$(vagrant awsinfo -m master -p | grep private_ip | cut -d '"' -f4)
NODE1_PRIVATE=$(vagrant awsinfo -m node1 -p | grep private_ip | cut -d '"' -f4)
NODE2_PRIVATE=$(vagrant awsinfo -m node2 -p | grep private_ip | cut -d '"' -f4)
echo "getting node IDs for cluster"

>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> TBC
NODE1_ID=$(vagrant awsinfo -m node1 -p | grep private_ip | cut -d '"' -f4)
NODE2_ID=$(vagrant awsinfo -m node2 -p | grep private_ip | cut -d '"' -f4)

echo "getting AWS info"
KEYPAIR_PATH=$(cat .aws_secrets | grep keypair_path | awk '{print $2}')
AWS_ACCESS_KEY_ID=$(cat .aws_secrets | grep access_key_id | awk '{print $2}')
AWS_SECRET_ACCESS_KEY=$(cat .aws_secrets | grep secret_access_key | awk '{print $2}')
AWS_REGION=$(cat .aws_secrets | grep region | awk '{print $2}')
AWS_ZONE=$(cat .aws_secrets | grep zone | awk '{print $2}')

wrap-scp() {
  scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $KEYPAIR_PATH $@
}

upload-cert() {
  local node=$1
  local certfolder=$2
  local file=$3
  local targetfile=$4
  wrap-scp $certfolder/$file ubuntu@$node:/tmp/flocker-copy-certs/$targetfile
}

setup-certs() {
  local certfolder=/tmp/certs$unixsecs
  mkdir -p $certfolder
  echo "generating certificates for the cluster"
  vagrant ssh master -c "CONTROL_IP=$MASTER_PRIVATE bash /tmp/generatecerts.sh"
  echo "downloading generated certs to $certfolder"
  wrap-scp ubuntu@$MASTER_PUBLIC:/tmp/flocker-certs/* $certfolder

  echo "creating /etc/flocker on all nodes"
  vagrant ssh master -c "sudo mkdir -p /etc/flocker && mkdir /tmp/flocker-copy-certs"
  vagrant ssh node1 -c "sudo mkdir -p /etc/flocker && mkdir /tmp/flocker-copy-certs"
  vagrant ssh node2 -c "sudo mkdir -p /etc/flocker && mkdir /tmp/flocker-copy-certs"

  echo "uploading cluster.crt"
  upload-file $MASTER_PUBLIC $certfolder cluster.crt
  upload-file $NODE1_PUBLIC $certfolder cluster.crt
  upload-file $NODE2_PUBLIC $certfolder cluster.crt

  echo "uploading control-service.{key,crt}"
  upload-file $MASTER_PUBLIC $certfolder control-service.crt
  upload-file $MASTER_PUBLIC $certfolder control-service.key

  echo "uploading node1.{key,crt}"
  upload-file $NODE1_PUBLIC $certfolder node1.crt node.crt
  upload-file $NODE1_PUBLIC $certfolder node1.key node.key

  echo "uploading node2.{key,crt}"
  upload-file $NODE2_PUBLIC $certfolder node2.crt node.crt
  upload-file $NODE2_PUBLIC $certfolder node2.key node.key

  echo "uploading plugin.{key,crt}"
  upload-file $NODE1_PUBLIC $certfolder plugin.crt
  upload-file $NODE1_PUBLIC $certfolder plugin.key
  upload-file $NODE2_PUBLIC $certfolder plugin.crt
  upload-file $NODE2_PUBLIC $certfolder plugin.key

  vagrant ssh master -c "sudo cp /tmp/flocker-copy-certs/* /etc/flocker && rm -rf /tmp/flocker-copy-certs && rm -rf /tmp/flocker-certs"
  vagrant ssh node1 -c "sudo cp /tmp/flocker-copy-certs/* /etc/flocker && rm -rf /tmp/flocker-copy-certs"
  vagrant ssh node2 -c "sudo cp /tmp/flocker-copy-certs/* /etc/flocker && rm -rf /tmp/flocker-copy-certs"
}

setup-slave() {
  echo "setup slave $1"
  local hostname=$1
  local address=$2
  vagrant ssh $hostname -c "sudo \
INSTALLER_TYPE=slave \
MASTER_IP=$MASTER_PRIVATE \
MY_ADDRESS=$address \
ATTRIBUTES='' \
AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
AWS_REGION=$AWS_REGION \
AWS_ZONE=$AWS_ZONE \
bash /tmp/install.sh"
}

setup-master() {
  echo "setup master"
  vagrant ssh master -c "sudo \
INSTALLER_TYPE=master \
MASTER_IP=$MASTER_PRIVATE \
MY_ADDRESS=$MASTER_PRIVATE \
ATTRIBUTES='' \
bash /tmp/install.sh"
}

setup-loadbalancer() {

}

setup-certs
setup-master
setup-slave node1 $NODE1_PRIVATE
setup-slave node2 $NODE2_PRIVATE
setup-loadbalancer

echo
echo "--------------------------------------------------------------------"
echo
echo "Cluster installed"
echo "Mesos Master: http://${MASTER_PUBLIC}:5050"
echo "Marathon Master: http://${MASTER_PUBLIC}:8080"
echo "Node1: ${NODE1_PUBLIC} ${NODE1_PRIVATE}"
echo "Node2: ${NODE2_PUBLIC} ${NODE2_PRIVATE}"