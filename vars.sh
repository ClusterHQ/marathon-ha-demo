#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
set -e

export RESET_CACHE=${RESET_CACHE:=""}
export AMI_ID=${AMI_ID:="ami-55a0c030"}
export INSTANCE_TYPE=${INSTANCE_TYPE:="c3.xlarge"}
export DATA_FOLDER=${DATA_FOLDER:="$HOME/.marathon-ha-demo"}
export PREPEND_TAG=${PREPEND_TAG:="marathon-ha-demo"}
export AWS_DEFAULT_OUTPUT="text"
export NODE_NAMES=(master node1 node2)