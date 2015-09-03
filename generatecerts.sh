#!/bin/bash -e

mkdir -p /tmp/flocker-certs
cd /tmp/flocker-certs
# cluster.crt
flocker-ca initialize marathon-ha
# control-service.crt
flocker-ca create-control-certificate ${CONTROL_IP}
mv control-*.crt control-service.crt
mv control-*.key control-service.key
# node1.crt
flocker-ca create-node-certificate
mv *-*-*.crt node1.crt
mv *-*-*.key node1.key
# node2.crt
flocker-ca create-node-certificate
mv *-*-*.crt node2.crt
mv *-*-*.key node2.key
# plugin.crt
flocker-ca create-api-certificate plugin