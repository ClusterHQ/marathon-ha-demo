#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
set -e

echo "####################################################################"
echo "#################### Installing Docker                      ########"
echo "####################################################################"

curl -sSL https://get.docker.com/ | sh

echo "####################################################################"
echo "#################### Installing Flocker                     ########"
echo "####################################################################"

apt-get -y install apt-transport-https software-properties-common
add-apt-repository -y "deb https://clusterhq-archive.s3.amazonaws.com/ubuntu/$(lsb_release --release --short)/\$(ARCH) /"
apt-get update
apt-get -y --force-yes install clusterhq-flocker-node clusterhq-flocker-cli

echo "####################################################################"
echo "#################### Installing Flocker Plugin              ########"
echo "####################################################################"

# install flocker plugin
apt-get -y install python-pip python-dev
pip install git+https://github.com/clusterhq/flocker-docker-plugin@master

echo "####################################################################"
echo "#################### Installing mesosphere                  ########"
echo "####################################################################"

# install mesos and marathon and then disable all services
# this means we can share the same base vagrant box between master and slaves

sudo apt-key adv --keyserver keyserver.ubuntu.com --recv E56151BF
DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
CODENAME=$(lsb_release -cs)

echo "deb http://repos.mesosphere.io/${DISTRO} ${CODENAME} main" | \
  sudo tee /etc/apt/sources.list.d/mesosphere.list
sudo apt-get -y update

sudo apt-get -y install mesos marathon

sudo service marathon stop || true
sudo sh -c "echo manual > /etc/init/marathon.override"

sudo service mesos-master stop || true
sudo sh -c "echo manual > /etc/init/mesos-master.override"

sudo service mesos-slave stop || true
sudo sh -c "echo manual > /etc/init/mesos-slave.override"

sudo service zookeeper stop || true
sudo sh -c "echo manual > /etc/init/zookeeper.override"

echo "####################################################################"
echo "#################### Pulling Docker Images                  ########"
echo "####################################################################"

# pre-pull required docker images
docker pull binocarlos/moby-counter:localfile