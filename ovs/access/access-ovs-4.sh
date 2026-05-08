#!/bin/sh

# Access-OVS-4
# eth0 -> PC1
# eth1 -> Dist-OVS-1
# eth2 -> Dist-OVS-2

set -e

ovs-vsctl --if-exists del-br br0
ovs-vsctl add-br br0
ovs-vsctl set bridge br0 rstp_enable=true

ovs-vsctl add-port br0 eth0
ovs-vsctl set port eth0 tag=10

ovs-vsctl add-port br0 eth1
ovs-vsctl set port eth1 trunks=10,20,99

ovs-vsctl add-port br0 eth2
ovs-vsctl set port eth2 trunks=10,20,99

ovs-vsctl show