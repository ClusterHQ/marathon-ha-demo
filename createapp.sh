#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
set -e

echo "Uploading Marathon manifest for application"

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/vars.sh
source $DIR/helpers.sh

MASTER_IP=$(get-public-ip-from-name master)
LOAD_BALANCER_DNS=$(get-load-balancer-dns)

cmd="curl -i -H 'Content-type: application/json' --data @app.json http://$MASTER_IP:8080/v2/groups"
echo $cmd
exec $cmd
echo "----------------------------------------"
echo "Application uploaded"
echo "You can view it's status in the Marathon GUI"
echo "You can open the application using the Load Balancer"
echo "-----------------------------------------"
echo "Marathon GUI:  http://$MASTER_PUBLIC:8080"
echo "Load Balancer: $LOAD_BALANCER_DNS"
echo "-----------------------------------------"