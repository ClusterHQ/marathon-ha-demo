#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
set -e

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# use the aws cli filters to filter the list of nodes based on name and running
# then extract the InstanceId using a query
get-node-property-from-name() {
  local NODE_NAME="$1"
  local PROPERTY="$2"
  aws ec2 describe-instances \
    --region $AWS_REGION \
    --filters "Name=tag:Name,Values=${PREPEND_TAG}-${NODE_NAME}" \
    "Name=instance-state-name,Values=pending,running" \
    --query "Reservations[0].Instances[0].${PROPERTY}"
}

# extract the instanceID of a node based on its name
get-node-id-from-name() {
  local NODE_NAME="$1"
  get-node-property-from-name $NODE_NAME InstanceId
}

# extract the public IP of a node based on its name
get-public-ip-from-name() {
  local NODE_NAME="$1"
  get-node-property-from-name $NODE_NAME PublicIpAddress
}

# extract the private IP of a node based on its name
get-private-ip-from-name() {
  local NODE_NAME="$1"
  get-node-property-from-name $NODE_NAME PrivateIpAddress
}



# get the current status of a node based on aws ec2 describe-instance-status
# if this is not "ok" then the node is not ready yet
get-node-status() {
  local NODE_ID="$1"
  aws ec2 describe-instance-status \
    --region $AWS_REGION \
    --instance-id $NODE_ID \
    --query "InstanceStatuses[0].InstanceStatus.Status"
}

# make the SCP commands shorter by wrapping the private key and connection opts
wrap-scp() {
  scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $KEY_PATH $@
}

# make the SSH commands shorter by wrapping the private key and connection opts
wrap-ssh() {
  ssh -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $KEY_PATH $@
}


# make a single AWS instance and return it's ID
# then tag it so we can query the instance based on it's name
create-aws-instance() {
  local NODE_NAME="$1"
  echo "Creating AWS Instance for: $NODE_NAME"
  # create the node and get the InstanceId using a query
  local NODE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --count 1 \
    --region $AWS_REGION \
    --placement AvailabilityZone=$AWS_ZONE \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --query 'Instances[0].InstanceId')
  # use the InstanceId to add name tags so we can map node name onto InstanceId
  aws ec2 create-tags \
    --region $AWS_REGION \
    --resource $NODE_ID \
    --tags "Key=\"Name\",Value=${PREPEND_TAG}-${NODE_NAME}"
}



# check if a given NODE_NAME exists and exit if true
# this is to prevent multiple copies of instances with the same name running at the same time
check-if-instance-exists() {
  local NODE_NAME="$1"
  local NODE_ID=$(get-node-id-from-name $NODE_NAME)
  if [[ "$NODE_ID" != "None" ]]; then
    >&2 echo "$NODE_NAME already exists - please terminate previous instances before creating a new cluster"
    exit 1
  fi
}

# loop over the list of hostnames and check if that instance already exists
check-for-existing-aws-instances() {
  for NODE_NAME in "${NODE_NAMES[@]}"
  do
    check-if-instance-exists $NODE_NAME
  done
}

# loop over the list of hostnames and create and instance before tagging it
create-aws-instances() {
  for NODE_NAME in "${NODE_NAMES[@]}"
  do
    create-aws-instance $NODE_NAME
  done
}

# remove the aws instance with the given name
remove-aws-instance() {
  local NODE_NAME="$1"
  local NODE_ID=$(get-node-id-from-name $NODE_NAME)
  local NODE_IP=$(get-public-ip-from-name $NODE_NAME)

  if [[ "$NODE_IP" != "None" ]]; then
    echo "Removing AWS Instance for: $NODE_NAME"
    aws ec2 terminate-instances \
      --region $AWS_REGION \
      --instance-ids $NODE_ID
  fi
}

# loop over the list of hostnames and remove each one
remove-aws-instances() {
  for NODE_NAME in "${NODE_NAMES[@]}"
  do
    remove-aws-instance $NODE_NAME
  done
}

# use the aws cli to determine if one instance is ready
# loop until the Status is ok
wait-for-instance() {
  local NODE_NAME="$1"
  local NODE_ID=$(get-node-id-from-name $NODE_NAME)
  echo "waiting for $NODE_NAME to be ready"
  local READY=""
  while [[ -z "$READY" ]]; do
    local NODE_STATUS=$(get-node-status $NODE_ID)
    if [[ "$NODE_STATUS" == "ok" ]]; then
      READY=1
    else
      echo -n "."
      sleep 5
    fi
  done
  echo "$NODE_NAME is now ready"
}

# loop over each instance and wait for it to be ready
wait-for-instances() {
  for NODE_NAME in "${NODE_NAMES[@]}"
  do
    wait-for-instance $NODE_NAME
  done
}

# get the DNS name for the load balancer
get-load-balancer-dns() {
    aws elb describe-load-balancers \
        --region $AWS_REGION \
        --load-balancer-names $LOAD_BALANCER_NAME \
        --query 'LoadBalancerDescriptions[0].DNSName'
}

# ensure that we don't aleady have a load balancer with the specific name
check-if-load-balancer-exists() {
  local LOAD_BALANCER=$(aws elb describe-load-balancers \
    --load-balancer-name $LOAD_BALANCER_NAME \
    --query 'LoadBalancerDescriptions[0].LoadBalancerName' 2>/dev/null )

  if [[ "$LOAD_BALANCER" == "$LOAD_BALANCER_NAME" ]]; then
    >&2 echo "$LOAD_BALANCER_NAME load balancer already exists - please delete the load balancer before creating a new cluster"
    exit 1
  fi
}

# create a load-balancer that gives us a static DNS that will dynamically
# route to the node the app is running on
create-load-balancer() {
  local NODE1_ID=$(get-node-id-from-name node1)
  local NODE2_ID=$(get-node-id-from-name node2)

  # create the load balancer configured to speak to the application port (8500)
  aws elb create-load-balancer \
    --availability-zones $AWS_ZONE \
    --region $AWS_REGION \
    --load-balancer-name $LOAD_BALANCER_NAME \
    --listeners "Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=8500"

  # add a health check that will route to where the application is running
  aws elb configure-health-check \
    --region $AWS_REGION \
    --load-balancer-name $LOAD_BALANCER_NAME \
    --health-check "Target=HTTP:8500/,Interval=5,UnhealthyThreshold=2,HealthyThreshold=2,Timeout=2"

  # add the 2 instances to the load balancer
  aws elb register-instances-with-load-balancer \
    --region $AWS_REGION \
    --load-balancer-name $LOAD_BALANCER_NAME \
    --instances $NODE1_ID $NODE2_ID
}

# remove the load-balancer
remove-load-balancer() {
  aws elb delete-load-balancer \
    --region $AWS_REGION \
    --load-balancer-name $LOAD_BALANCER_NAME
}