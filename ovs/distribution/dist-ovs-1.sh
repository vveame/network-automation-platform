#!/bin/sh

# Dist-OVS-1
# eth0 -> Access-OVS-4
# eth1 -> Access-OVS-5
# eth2 -> Access-OVS-6
# eth3 -> Dist-FRR-1

ovs-vsctl --if-exists del-br br0
ovs-vsctl add-br br0
ovs-vsctl set bridge br0 rstp_enable=true

ovs-vsctl add-port br0 eth0
ovs-vsctl set port eth0 trunks=10,20,99

ovs-vsctl add-port br0 eth1
ovs-vsctl set port eth1 trunks=10,20,99

ovs-vsctl add-port br0 eth2
ovs-vsctl set port eth2 trunks=10,20,99

ovs-vsctl add-port br0 eth3
ovs-vsctl set port eth3 trunks=10,20,99

ovs-vsctl show