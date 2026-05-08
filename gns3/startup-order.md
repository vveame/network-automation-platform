# GNS3 Startup Order

This file defines the recommended startup and validation order for the GNS3 topology.

## Startup Order

1. Start Open vSwitch nodes.
2. Start FRRouting routers.
3. Start VPCS hosts.
4. Start DevOps, Web and DNS servers.
5. Start the External / Cloud / Internet Gateway node.
6. Verify OVS bridges and VLAN/trunk configuration.
7. Verify OVS management IPs.
8. Verify FRR interfaces and routing configuration.
9. Verify OSPF neighbors.
10. Verify VRRP gateway state.
11. Validate end-to-end connectivity.
12. Apply or verify security rules.
13. Verify NAT only to external/cloud interface is connected and enabled.

## Validation Commands

### On OVS nodes

```bash
ovs-vsctl show
ip -br addr
ip route
```

### On FRR routers

```bash
ip -br addr
ip route
vtysh -c "show ip route"
vtysh -c "show ip ospf neighbor"
vtysh -c "show vrrp"
```

### On Linux servers

```bash
ip addr
ip route
ping <gateway-ip>
```

### On VPCS hosts

```bash
On VPCS hosts
```

## Notes

- OVS configuration must be applied before OVS management IP configuration because mgmt0 depends on br0.
- FRR interface configuration must be applied before starting or validating OSPF and VRRP.
- OSPF authentication requires the local secret file /etc/local/ospf.env.
- NAT should only be enabled on the EdgeRouter when eth3 is connected to an external/cloud gateway.