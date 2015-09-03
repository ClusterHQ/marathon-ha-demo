#!/bin/bash -e

echo "####################################################################"
echo "#################### Installing mesosphere $INSTALLER_TYPE #########"
echo "####################################################################"

mesos-master() {
  mkdir -p /etc/zookeeper/conf
  mkdir -p /etc/mesos
  mkdir -p /etc/mesos-master
  mkdir -p /etc/marathon/conf
  echo "1" > /etc/zookeeper/conf/myid
  echo "server.1=$MASTER_IP:2888:3888" >> /etc/zookeeper/conf/zoo.cfg
  echo "zk://$MASTER_IP:2181/mesos" > /etc/mesos/zk
  cp /etc/mesos/zk /etc/marathon/conf/master
  echo "zk://$MASTER_IP:2181/marathon" > /etc/marathon/conf/zk
  #echo "1" > /etc/mesos-master/quorum
  echo "$MY_ADDRESS" > /etc/mesos-master/hostname
  echo "$MY_ADDRESS" > /etc/mesos-master/ip
  echo "$MY_ADDRESS" > /etc/marathon/conf/hostname
  
  rm /etc/init/zookeeper.override
  rm /etc/init/mesos-master.override
  rm /etc/init/marathon.override
  sudo service zookeeper start
  sudo service mesos-master start
  sudo service marathon start
}

mesos-slave() {
  mkdir -p /etc/mesos
  mkdir -p /etc/mesos-slave
  mkdir -p /etc/marathon/conf
  echo 'docker,mesos' > /etc/mesos-slave/containerizers
  echo "$ATTRIBUTES" > /etc/mesos-slave/attributes
  echo '5mins' > /etc/mesos-slave/executor_registration_timeout
  echo "zk://$MASTER_IP:2181/mesos" > /etc/mesos/zk
  echo "ports:[7000-9000]" > /etc/mesos-slave/resources
  echo "$MY_ADDRESS" > /etc/mesos-slave/hostname
  echo "$MY_ADDRESS" > /etc/mesos-slave/ip
  echo "$MY_ADDRESS" > /etc/marathon/conf/hostname
  rm /etc/init/mesos-slave.override

  sleep 10
  sudo service mesos-slave start
}

flocker-control() {
  cat <<EOF > /etc/init/flocker-control.override
start on runlevel [2345]
stop on runlevel [016]
EOF
  echo 'flocker-control-api       4523/tcp                        # Flocker Control API port' >> /etc/services
  echo 'flocker-control-agent     4524/tcp                        # Flocker Control Agent port' >> /etc/services
  service flocker-control restart
  ufw allow flocker-control-api
  ufw allow flocker-control-agent
}

flocker-plugin() {
  cat <<EOF > /etc/init/flocker-docker-plugin.conf
# flocker-plugin - flocker-docker-plugin job file

description "Flocker Plugin service"
author "ClusterHQ <support@clusterhq.com>"

respawn
env FLOCKER_CONTROL_SERVICE_BASE_URL=https://${MASTER_IP}:4523/v1
env MY_NETWORK_IDENTITY=${MY_ADDRESS}
exec /usr/local/bin/flocker-docker-plugin
EOF
  service flocker-docker-plugin restart
}

flocker-agent() {
  mkdir -p /etc/flocker
cat <<EOF > /etc/flocker/agent.yml
"version": 1
"control-service":
   "hostname": "${MASTER_IP}"
   "port": 4524
"dataset":
   "backend": "aws"
   "region": "${AWS_REGION}"
   "zone": "${AWS_ZONE}"
   "access_key_id": "${AWS_ACCESS_KEY_ID}"
   "secret_access_key": "${AWS_SECRET_ACCESS_KEY}"
EOF
  service flocker-container-agent restart
  service flocker-dataset-agent restart
}


flocker-master() {
  flocker-control
}

flocker-slave() {
  flocker-agent
  flocker-plugin
}

master() {
  mesos-master
  flocker-master
}

slave() {
  mesos-slave
  flocker-slave
}

if [[ "$INSTALLER_TYPE" == "master" ]]; then
  master
else
  slave
fi