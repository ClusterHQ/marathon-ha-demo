#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
set -e

echo "Launching cluster"

unixsecs=$(date +%s)

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/vars.sh
source $DIR/helpers.sh

# setup the cache folder
initialize() {
  if [[ -n "$RESET_CACHE" ]]; then
    rm -rf $DATA_FOLDER
  fi
  mkdir -p $DATA_FOLDER
}

# ensure the environment variables we require are defined
check-variables() {
  if [[ -z "$KEY_NAME" ]]; then
    >&2 echo "Please specify a KEY_NAME that is the name of the key-pair you have created"
    exit 1
  fi
  if [[ -z "$KEY_PATH" ]]; then
    >&2 echo "Please specify a KEY_PATH that is the path of the private key for the key-pair"
    exit 1
  fi
}

# loop over the list of hostnames and create and instance before tagging it
create-aws-instances() {
  # create the 3 instances
  echo "running aws ec2 run-instances for 3 nodes"
  aws ec2 run-instances --image-id $AMI_ID --count 3 --instance-type $INSTANCE_TYPE --key-name $KEY_NAME > $DATA_FOLDER/nodes.json
  # loop over them and assign a Name tag
  local COUNTER=0
  for NODE_ID in `cat $DATA_FOLDER/nodes.json | grep InstanceId | cut -d '"' -f4`; do
    # extract the name from the array of node names
    local NODE_NAME=${NODE_NAMES[$COUNTER]}
    echo "creating name tag for $NODE_NAME - ($NODE_ID)"
    # create the tag for the node name
    aws ec2 create-tags --resource $NODE_ID --tags "Key=\"Name\",Value=${PREPEND_TAG}-${NODE_NAME}"
    # keep a local cache of values for this node
    echo "id: $NODE_ID" > $DATA_FOLDER/$NODE_NAME.txt
    # counter to map id onto hostname
    COUNTER=$[$COUNTER +1]
  done
}

# use the aws cli to determine if one instance is ready
wait-for-instance() {
  local NODE_NAME="$1"
  local NODE_ID=$(get-node-id-from-name $NODE_NAME)
  echo "waiting for $NODE_NAME instance to be ready"
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
  echo ""
  echo "$NODE_NAME is now ready"
}

# loop over each instance and wait for it to be ready
wait-for-instances() {
  for NODE_NAME in "${NODE_NAMES[@]}"
  do
    wait-for-instance $NODE_NAME
  done
}

# write the public and private IPS for a node to the cache
cache-instance-ip() {
  local NODE_NAME="$1"
  local NODE_ID=$(get-node-id-from-name $NODE_NAME)
  local INFO=$(aws ec2 describe-instances --instance-ids $NODE_ID)
  echo $INFO
  exit
  local PUBLIC_IP=$(echo $INFO | grep PublicIpAddress | awk '{print $2}' | sed 's/"//g')
  local PRIVATE_IP=$(echo $INFO | grep PrivateIpAddress | awk '{print $2}' | sed 's/"//g')
  echo $NODE_NAME
  echo "public ip: $PUBLIC_IP"
  echo "PRIVATE_IP ip: $PRIVATE_IP"
  #echo "id: $NODE_ID" >> $DATA_FOLDER/$NODE_NAME.txt
}

# loop over each node and cache the IP addresses
cache-instance-ips() {
  for NODE_NAME in "${NODE_NAMES[@]}"
  do
    cache-instance-ip $NODE_NAME
  done
}

#check-variables
#initialize
#create-aws-instances
#wait-for-instances
cache-instance-ips