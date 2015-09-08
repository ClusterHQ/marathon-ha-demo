#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
set -e

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# use the aws cli filters to filter the list of nodes based on name and running
# then extract the InstanceId using a query
get-node-property-from-name() {
  local NODE_NAME="$1"
  local PROPERTY="$2"
  aws ec2 describe-instances \
    --region $AWS_REGION \
    --filters "Name=tag:Name,Values=marathon-ha-demo-${NODE_NAME}" \
    "Name=instance-state-name,Values=pending,running" \
    --query "Reservations[0].Instances[0].${PROPERTY}"
}

# extract the instanceID of a node based on its name
get-node-id-from-name() {
  local NODE_NAME="$1"
  get-node-property-from-name $NODE_NAME InstanceId
}

# extract the public IP of a node based on its name
get-public-ip-from-name() {
  local NODE_NAME="$1"
  get-node-property-from-name $NODE_NAME PublicIpAddress
}

# extract the private IP of a node based on its name
get-private-ip-from-name() {
  local NODE_NAME="$1"
  get-node-property-from-name $NODE_NAME PrivateIpAddress
}

# get the current status of a node based on aws ec2 describe-instance-status
# if this is not "ok" then the node is not ready yet
get-node-status() {
  local NODE_ID="$1"
  aws ec2 describe-instance-status \
    --region $AWS_REGION \
    --instance-id $NODE_ID \
    --query "InstanceStatuses[0].InstanceStatus.Status"
}

# make the SCP commands shorter by wrapping the private key and connection opts
wrap-scp() {
  scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $KEY_PATH $@
}

# make the SSH commands shorter by wrapping the private key and connection opts
wrap-ssh() {
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $KEY_PATH $@
}
