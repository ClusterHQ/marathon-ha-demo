#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
set -e

echo "Launching cluster"

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/vars.sh
source $DIR/helpers.sh

# make a single AWS instance and return it's ID
# then tag it so we can query the instance based on it's name
create-aws-instance() {
  local NODE_NAME="$1"
  echo "Creating AWS Instance for: $NODE_NAME"
  # create the node and get the InstanceId using a query
  local NODE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --count 1 \
    --region $AWS_REGION \
    --placement AvailabilityZone=$AWS_ZONE \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --query 'Instances[0].InstanceId')
  # use the InstanceId to add name tags so we can map node name onto InstanceId
  aws ec2 create-tags \
    --region $AWS_REGION \
    --resource $NODE_ID \
    --tags "Key=\"Name\",Value=${PREPEND_TAG}-${NODE_NAME}"
}

# check if a given NODE_NAME exists and exit if true
# this is to prevent multiple copies of instances with the same name running at the same time
check-if-instance-exists() {
  local NODE_NAME="$1"
  local NODE_ID=$(get-node-id-from-name $NODE_NAME)
  if [[ "$NODE_ID" != "None" ]]; then
    >&2 echo "$NODE_NAME already exists - please terminate previous instances before creating a new cluster"
    exit 1
  fi
}

# loop over the list of hostnames and create and instance before tagging it
create-aws-instances() {
  for NODE_NAME in "${NODE_NAMES[@]}"
  do
    check-if-instance-exists $NODE_NAME
  done

  for NODE_NAME in "${NODE_NAMES[@]}"
  do
    create-aws-instance $NODE_NAME
  done
}

# use the aws cli to determine if one instance is ready
# loop until the Status is ok
wait-for-instance() {
  local NODE_NAME="$1"
  local NODE_ID=$(get-node-id-from-name $NODE_NAME)
  echo "waiting for $NODE_NAME to be ready"
  local READY=""
  while [[ -z "$READY" ]]; do
    local NODE_STATUS=$(get-node-status $NODE_ID)
    if [[ "$NODE_STATUS" == "ok" ]]; then
      READY=1
    else
      echo -n "."
      sleep 5
    fi
  done
  echo "$NODE_NAME is now ready"
}

# loop over each instance and wait for it to be ready
wait-for-instances() {
  for NODE_NAME in "${NODE_NAMES[@]}"
  do
    wait-for-instance $NODE_NAME
  done
}

# ensure that we don't aleady have a load balancer with the specific name
check-if-load-balancer-exists() {

}

# create a load-balancer that gives us a static DNS that will dynamically
# route to the node the app is running on
create-load-balancer() {
  local LOAD_BALANCER_NAME="${PREPEND_TAG}-elb"
  local NODE1_ID=$(get-node-id-from-name node1)
  local NODE2_ID=$(get-node-id-from-name node2)
  aws elb create-load-balancer \
    --load-balancer-name $LOAD_BALANCER_NAME \
    --listeners "Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=8500" \
    --availability-zones $AWS_ZONE \
    --region $AWS_REGION

  aws elb configure-health-check \
    --load-balancer-name $LOAD_BALANCER_NAME \
    --health-check "Target=HTTP:8500/,Interval=5,UnhealthyThreshold=2,HealthyThreshold=2,Timeout=2"

  aws elb register-instances-with-load-balancer \
    --load-balancer-name $LOAD_BALANCER_NAME \
    --instances $NODE1_ID $NODE2_ID
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

check-variables
create-aws-instances
wait-for-instances
prepare-instances
setup-certs
setup-master
setup-slave node1
setup-slave node2
