#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
set -e

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/vars.sh
source $DIR/helpers.sh

MASTER_PUBLIC=$(get-public-ip-from-name master)
NODE1_PUBLIC=$(get-public-ip-from-name node1)
NODE2_PUBLIC=$(get-public-ip-from-name node2)
MASTER_PRIVATE=$(get-private-ip-from-name master)
NODE1_PRIVATE=$(get-private-ip-from-name node1)
NODE2_PRIVATE=$(get-private-ip-from-name node2)
LOAD_BALANCER_DNS=$(get-load-balancer-dns)

if [[ "$MASTER_PUBLIC" == "None" ]]; then
    >&2 echo "The master node cannot be found - please run 'make cluster' to create the required resources"
    exit 1
else
    echo "-----------------------------------------"    
    echo "Master IPs:    $MASTER_PUBLIC - $MASTER_PRIVATE"
    echo "Node 1 IPs:    $NODE1_PUBLIC - $NODE1_PRIVATE"
    echo "Node 2 IPs:    $NODE2_PUBLIC - $NODE2_PRIVATE"
    echo "-----------------------------------------"
    echo "Marathon GUI:  http://$MASTER_PUBLIC:8080"
    echo "Mesos GUI:     http://$MASTER_PUBLIC:5050"
    echo "Load Balancer: $LOAD_BALANCER_DNS"
    echo "-----------------------------------------"
fi

