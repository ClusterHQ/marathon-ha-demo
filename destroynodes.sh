#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
set -e

echo "Destroying cluster"

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/vars.sh

destroy-node() {
  local name="$1"
  local id=$(cat $DATA_FOLDER/$name.txt | grep "id: " | awk '{print $2}')
  echo "destroying node $name ($id)"
  aws ec2 terminate-instances --instance-ids $id > /dev/null
}

destroy-node master
destroy-node node1
destroy-node node2
rm -rf $DATA_FOLDER