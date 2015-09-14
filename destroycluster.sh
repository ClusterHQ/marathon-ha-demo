#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
set -e

echo "Destroying cluster"

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/vars.sh
source $DIR/helpers.sh

remove-load-balancer
remove-aws-instances