#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
set -e

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

get-node-property-from-name() {
  local $NODE_NAME="$1"
  local $PROPERTY="$2"
  aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=marathon-ha-demo-${NODE_NAME}" \
    "Name=instance-state-name,Values=pending,running" \
    --query "Reservations[0].Instances[0].${PROPERTY}"
}

# extract the instanceID of a node based on its name
get-node-id-from-name() {
  local $NODE_NAME="$1"
  get-node-property-from-name $NODE_NAME InstanceId
}

# extract the public IP of a node based on its name
get-public-id-from-name() {
  local $NODE_NAME="$1"
  get-node-property-from-name $NODE_NAME PublicIpAddress
}

# extract the private IP of a node based on its name
get-private-id-from-name() {
  local $NODE_NAME="$1"
  get-node-property-from-name $NODE_NAME PrivateIpAddress
}

# get the current status of a node based on aws ec2 describe-instance-status
get-node-status() {
  local instanceid="$1"
  aws ec2 describe-instance-status --instance-id $instanceid --query "InstanceStatuses[0].InstanceStatus.Status"
}