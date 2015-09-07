#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
set -e

echo "Launching cluster"

unixsecs=$(date +%s)

export RESET_CACHE=${RESET_CACHE:=""}
export AMI_ID=${AMI_ID:="ami-55a0c030"}
export INSTANCE_TYPE=${INSTANCE_TYPE:="c3.xlarge"}
export DATA_FOLDER=${DATA_FOLDER:="$HOME/.marathon-ha-demo"}
export PREPEND_TAG=${PREPEND_TAG:="marathon-ha-demo"}
export AWS_DEFAULT_OUTPUT="json"
export NODE_NAMES=(master node1 node2)

initialize() {
  if [[ -n "$RESET_CACHE" ]]; then
    rm -rf $DATA_FOLDER
  fi
  mkdir -p $DATA_FOLDER
}

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

check-variables
initialize
create-aws-instances