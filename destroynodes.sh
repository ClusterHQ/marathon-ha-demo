#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
set -e

echo "Destroying cluster"

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/vars.sh
source $DIR/helpers.sh

destroy-node() {
  local NODE_NAME="$1"
  local NODE_ID=$(get-node-id-from-name $NODE_NAME)
  echo "destroying node $NODE_NAME ($NODE_ID)"
  aws ec2 terminate-instances --instance-ids $NODE_ID > /dev/null
}

destroy-node master
destroy-node node1
destroy-node node2