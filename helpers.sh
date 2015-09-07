#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
set -e

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# turn a nodename into it's instance id based on the cache we wrote when creating the nodes
get-node-id-from-name() {
  local $NODE_NAME="$1"
  cat $DATA_FOLDER/$NODE_NAME.txt | grep id | awk '{print $2}'
}

# get the current status of a node based on aws ec2 describe-instance-status
get-node-status() {
  local instanceid="$1"
  aws ec2 describe-instance-status --instance-id $instanceid --query 'InstanceStatuses[0].InstanceStatus.Status'
}

jq() {
  local path="$1"
  cat | bash $DIR/json.sh | grep "\\$path" | awk '{print $2}' | sed 's/"//g'
}