#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
set -e

export RESET_CACHE=${RESET_CACHE:=""}
export AMI_ID=${AMI_ID:="ami-55a0c030"}
export INSTANCE_TYPE=${INSTANCE_TYPE:="c3.large"}
export PREPEND_TAG=${PREPEND_TAG:="marathon-ha-demo"}
export AWS_DEFAULT_OUTPUT="text"
export NODE_NAMES=(master node1 node2)
export AWS_ACCESS_KEY_ID=$(cat ~/.aws/credentials | grep aws_access_key_id | awk '{print $3}')
export AWS_SECRET_ACCESS_KEY=$(cat ~/.aws/credentials | grep aws_secret_access_key | awk '{print $3}')
# the region is fixed because this is where we have made the AMI
export AWS_REGION="us-east-1"
# pick the first available zone within the region by asking AWS for it
export AWS_ZONE=$(aws ec2 describe-availability-zones \
    --region $AWS_REGION \
    --query 'AvailabilityZones[0].ZoneName' \
    --filter 'Name=state,Values=available')

# ensure the environment variables we require are defined
check-variables() {
  if [[ -z "$KEY_NAME" ]]; then
    >&2 echo "Please specify a KEY_NAME that is the name of the key-pair you have created"
    exit 1
  fi
  if [[ -z "$KEY_PATH" ]]; then
    >&2 echo "Please specify a KEY_PATH that is the path of the private key for the key-pair"
    exit 1
  fi
}

check-variables