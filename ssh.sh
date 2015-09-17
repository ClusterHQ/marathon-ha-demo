#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
set -e

# quick way to ssh into one of the machines

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/vars.sh
source $DIR/helpers.sh

if [[ -z "$1" ]]; then
    >&2 echo "usage bash ssh.sh <nodename>"
    exit 1
fi

IP_ADDRESS=$(get-public-ip-from-name $1)
wrap-ssh ubuntu@$IP_ADDRESS
