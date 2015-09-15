#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
set -e

# this asks Marathon
echo "Terminating the node the application is running on"

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/vars.sh
source $DIR/helpers.sh

MASTER_IP=$(get-public-ip-from-name master)
APP_IP=$(curl -sS http://$MASTER_IP:8080/v2/apps/marathon-ha-demo/moby-counter | \
    sed 's/^.*host":"//' | \
    sed 's/".*$//')

APP_NODE_NAME=""

for NODE_NAME in node1 node2; do
    NODE_PRIVATE_IP=$(get-private-ip-from-name $NODE_NAME)
    if [[ "$NODE_PRIVATE_IP" == "$APP_IP" ]]; then
        APP_NODE_NAME="$NODE_NAME"
    fi
done

if [[ -z "$APP_NODE_NAME" ]]; then
    >&2 echo "Have been unable to locate the application on the cluster"
    exit 1
fi

remove-aws-instance $APP_NODE_NAME