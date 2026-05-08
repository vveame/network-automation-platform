#!/bin/sh

# Access-OVS-6
# eth0 -> PC3
# eth1 -> DevOps Server
# eth2 -> Dist-OVS-1
# eth3 -> Dist-OVS-2

set -e

ovs-vsctl --if-exists del-br br0
ovs-vsctl add-br br0
ovs-vsctl set bridge br0 rstp_enable=true

ovs-vsctl add-port br0 eth0
ovs-vsctl set port eth0 tag=20

ovs-vsctl add-port br0 eth1
ovs-vsctl set port eth1 tag=99

ovs-vsctl add-port br0 eth2
ovs-vsctl set port eth2 trunks=10,20,99

ovs-vsctl add-port br0 eth3
ovs-vsctl set port eth3 trunks=10,20,99

ovs-vsctl show