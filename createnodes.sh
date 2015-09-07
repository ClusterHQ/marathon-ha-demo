#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
set -e

echo "Launching cluster"

unixsecs=$(date +%s)

export AMI_ID=${AMI_ID:="ami-55a0c030"}
export INSTANCE_TYPE=${INSTANCE_TYPE:="c3.xlarge"}
export DATA_FOLDER=${DATA_FOLDER:="$HOME/.marathon-ha-demo"}
export AWS_DEFAULT_OUTPUT="json"
export NODE_NAMES=(master node1 node2)

initialize() {
  mkdir -p $DATA_FOLDER
}

check-variables() {
  if [[ -z "$KEYNAME" ]]; then
    >&2 echo "Please specify a KEYNAME that is the name of the key-pair you have created"
    exit 1
  fi
}

create-aws-instances() {
  # create the 3 instances
  #aws ec2 run-instances --image-id $AMI_ID --count 3 --instance-type $INSTANCE_TYPE --key-name $KEYNAME > $DATA_FOLDER/nodes.json
  # loop over them and assign a Name tag
  local COUNTER=0
  for i in `cat $DATA_FOLDER/nodes.json | grep InstanceId | cut -d '"' -f4`; do
    aws ec2 create-tags --resource i-52a17af1 --tags 'Key="Name",Value=master'
    echo "$i is the ID"
    local name=${NODE_NAMES[$COUNTER]}
    echo "$name is the name"
    echo "counter = $COUNTER"
    COUNTER=$[$COUNTER +1]
  done
}

initialize
check-variables
create-aws-instances