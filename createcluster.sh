#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
set -e

echo "Launching cluster"

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/vars.sh
source $DIR/helpers.sh

# check the required variables and then
# see if we have any nodes or load-balancers from previous runs
check-status() {
  check-variables
  check-for-existing-aws-instances
  check-if-load-balancer-exists
}

# upload the contents of ./uploads to each node
# these scripts are used to create certs and provision the cluster
prepare-instance() {
  local NODE_NAME="$1"
  local NODE_IP=$(get-public-ip-from-name $NODE_NAME)
  echo "Uploading provisioning scripts to $NODE_NAME"
  wrap-scp $DIR/uploads/* ubuntu@$NODE_IP:/tmp
  echo "Creating required folders on $NODE_NAME"
  wrap-ssh ubuntu@$NODE_IP "sudo mkdir -p /etc/flocker && mkdir -p /tmp/flocker-copy-certs"
}

# prepare the nodes with the provisioning scripts
prepare-instances() {
  for NODE_NAME in "${NODE_NAMES[@]}"
  do
    prepare-instance $NODE_NAME
  done
}

# upload a certificate to a node from the local cache of certs
# /tmp/flocker-copy-certs is a place we can upload to as ubuntu
# we then sudo cp /tmp/flocker-copy-certs /etc/flocker in one go
upload-cert() {
  local NODE_IP="$1"
  local LOCAL_CERTS="$2"
  local FILE="$3"
  local TARGET_FILE="$4"
  wrap-scp $LOCAL_CERTS/$FILE ubuntu@$NODE_IP:/tmp/flocker-copy-certs/$TARGET_FILE
}

# run the generate certs script on the master and then download the files that were created
# then distribute the certs across the nodes accordingly
setup-certs() {

  # get the public/private IP addresses for the nodes
  local MASTER_PUBLIC=$(get-public-ip-from-name master)
  local MASTER_PRIVATE=$(get-private-ip-from-name master)
  local NODE1_PUBLIC=$(get-public-ip-from-name node1)
  local NODE2_PUBLIC=$(get-public-ip-from-name node2)

  # make a temporary local folder in which to save the downloaded certs
  local UNIXSECS=$(date +%s)
  local CERTFOLDER="/tmp/certs${UNIXSECS}"
  mkdir -p $CERTFOLDER

  # generate the certificates on the master node (where flocker-ca is installed)
  echo "generating certificates for the cluster"
  wrap-ssh ubuntu@$MASTER_PUBLIC CONTROL_IP=$MASTER_PRIVATE bash /tmp/generatecerts.sh

  # SCP the certs generated on the master down into the local folder we created for them
  echo "downloading generated certs to $CERTFOLDER"
  wrap-scp ubuntu@$MASTER_PUBLIC:/tmp/flocker-certs/* $CERTFOLDER

  # now we start to distribute the certs across the 3 nodes
  echo "uploading cluster.crt"
  upload-cert $MASTER_PUBLIC $CERTFOLDER cluster.crt
  upload-cert $NODE1_PUBLIC $CERTFOLDER cluster.crt
  upload-cert $NODE2_PUBLIC $CERTFOLDER cluster.crt

  echo "uploading control-service.{key,crt}"
  upload-cert $MASTER_PUBLIC $CERTFOLDER control-service.crt
  upload-cert $MASTER_PUBLIC $CERTFOLDER control-service.key

  echo "uploading node1.{key,crt}"
  upload-cert $NODE1_PUBLIC $CERTFOLDER node1.crt node.crt
  upload-cert $NODE1_PUBLIC $CERTFOLDER node1.key node.key

  echo "uploading node2.{key,crt}"
  upload-cert $NODE2_PUBLIC $CERTFOLDER node2.crt node.crt
  upload-cert $NODE2_PUBLIC $CERTFOLDER node2.key node.key

  echo "uploading plugin.{key,crt}"
  upload-cert $NODE1_PUBLIC $CERTFOLDER plugin.crt
  upload-cert $NODE1_PUBLIC $CERTFOLDER plugin.key
  upload-cert $NODE2_PUBLIC $CERTFOLDER plugin.crt
  upload-cert $NODE2_PUBLIC $CERTFOLDER plugin.key

  wrap-ssh ubuntu@$MASTER_PUBLIC "sudo cp /tmp/flocker-copy-certs/* /etc/flocker && rm -rf /tmp/flocker-copy-certs && rm -rf /tmp/flocker-certs"
  wrap-ssh ubuntu@$NODE1_PUBLIC "sudo cp /tmp/flocker-copy-certs/* /etc/flocker && rm -rf /tmp/flocker-copy-certs"
  wrap-ssh ubuntu@$NODE2_PUBLIC "sudo cp /tmp/flocker-copy-certs/* /etc/flocker && rm -rf /tmp/flocker-copy-certs"

  # remove the temp folder we created for the certs
  rm -rf $CERTFOLDER
}

setup-slave() {
  local NODE_NAME="$1"
  local PUBLIC_IP=$(get-public-ip-from-name $NODE_NAME)
  local PRIVATE_IP=$(get-private-ip-from-name $NODE_NAME)
  local MASTER_PRIVATE=$(get-private-ip-from-name master)

  echo "setting up slave: $NODE_NAME"

  wrap-ssh ubuntu@$PUBLIC_IP sudo \
INSTALLER_TYPE=slave \
MASTER_IP=$MASTER_PRIVATE \
MY_ADDRESS=$PRIVATE_IP \
ATTRIBUTES='' \
AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
AWS_REGION=$AWS_REGION \
AWS_ZONE=$AWS_ZONE \
bash /tmp/install.sh
}

setup-master() {
  local MASTER_PUBLIC=$(get-public-ip-from-name master)
  local MASTER_PRIVATE=$(get-private-ip-from-name master)

  echo "setting up master"

  wrap-ssh ubuntu@$MASTER_PUBLIC sudo \
INSTALLER_TYPE=master \
MASTER_IP=$MASTER_PRIVATE \
MY_ADDRESS=$MASTER_PRIVATE \
ATTRIBUTES='' \
bash /tmp/install.sh
}

check-status
create-aws-instances
wait-for-instances
prepare-instances
setup-certs
setup-master
setup-slave node1
setup-slave node2
