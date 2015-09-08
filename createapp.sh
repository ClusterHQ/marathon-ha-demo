#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
set -e

echo "Uploading Marathon manifest for application"

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/vars.sh
source $DIR/helpers.sh

MASTER_IP=$(get-public-ip-from-name master)

curl -i -H 'Content-type: application/json' --data @app.json http://$MASTER_IP:8080/v2/groups