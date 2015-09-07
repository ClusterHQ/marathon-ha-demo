#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
set -e

echo "Launching cluster"

unixsecs=$(date +%s)

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/vars.sh
source $DIR/helpers.sh

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

# make a single AWS instance and return it's ID
# then tag it so we can query the instance based on it's name
create-aws-instance() {
  local NODE_NAME="$1"
  echo "Creating AWS Instance for: $NODE_NAME"
  local NODE_ID=$(aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type $INSTANCE_TYPE --key-name $KEY_NAME --query 'Instances[0].InstanceId')
  aws ec2 create-tags --resource $NODE_ID --tags "Key=\"Name\",Value=${PREPEND_TAG}-${NODE_NAME}"
}

# check if a given NODE_NAME exists and exit if true
# this is to prevent multiple copies of instances with the same name running at the same time
check-if-instance-exists() {
  local NODE_NAME="$1"
  local NODE_ID=$(get-node-id-from-name $NODE_NAME)
  if [[ -n "$NODE_ID" ]]; then
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

check-variables
create-aws-instances
wait-for-instances