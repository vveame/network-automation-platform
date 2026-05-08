#!/bin/sh

# DMZ-OVS
# eth0 -> Web Server
# eth1 -> DNS Server
# eth2 -> EdgeRouter

set -e

ovs-vsctl --if-exists del-br br0
ovs-vsctl add-br br0

ovs-vsctl add-port br0 eth0
ovs-vsctl add-port br0 eth1
ovs-vsctl add-port br0 eth2

ovs-vsctl show