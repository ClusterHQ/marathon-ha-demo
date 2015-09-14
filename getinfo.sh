#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
set -e

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/vars.sh
source $DIR/helpers.sh

MASTER_PUBLIC=$(get-public-ip-from-name master)
NODE1_PUBLIC=$(get-public-ip-from-name node1)
NODE2_PUBLIC=$(get-public-ip-from-name node2)

echo "-----------------------------------------"
echo "Marathon GUI: http://$MASTER_PUBLIC:8080"
echo "Mesos GUI: http://$MASTER_PUBLIC:5050"
echo "Node 1 IP: $NODE1_PUBLIC"
echo "Node 2 IP: $NODE2_PUBLIC"
echo "-----------------------------------------"