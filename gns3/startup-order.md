# GNS3 Startup and Validation Order

This file defines the recommended order for starting and validating the local GNS3 topology.

## Startup Order

1. Start the GNS3 VM.
2. Start or verify the dedicated DevOps VM.
3. Verify the DevOps VM OOB interface.
4. Start OVS nodes.
5. Start FRR routers.
6. Start DMZ service nodes: Web and DNS.
7. Start VPCS endpoint hosts.
8. Run the persistent bootstrap when containers may be stopped or exited.
9. Run the running-container bootstrap when all containers are already running and immediate application is required.
10. Validate OOB reachability from the DevOps VM.
11. Run Ansible management readiness checks.
12. Run Ansible SSH readiness checks.
13. Run full Ansible validation from the DevOps VM.

## DevOps VM Interface Check

From the DevOps VM:

```bash
ip -br addr
ip route
```

Expected:

```text
ens33  DHCP through VMware NAT
ens34  10.200.0.10/24
```

The default route should stay on the NAT interface. The OOB interface should not be used as the default gateway.

## Bootstrap Commands

From the GNS3 VM:

```bash
cd /home/gns3/pfe-repo
./bootstrap-persistent-gns3.sh
```

Use the running-container bootstrap only after all nodes are already started:

```bash
./bootstrap-gns3.sh
```

## DevOps VM Validation Commands

From the DevOps VM:

```bash
for ip in \
  10.200.0.11 \
  10.200.0.12 \
  10.200.0.21 \
  10.200.0.22 \
  10.200.0.30 \
  10.200.0.31 \
  10.200.0.32 \
  10.200.0.33 \
  10.200.0.44 \
  10.200.0.45 \
  10.200.0.46
do
  echo "===== PING $ip ====="
  ping -c 2 -W 2 "$ip"
done
```

SSH validation:

```bash
for ip in \
  10.200.0.11 \
  10.200.0.12 \
  10.200.0.21 \
  10.200.0.22 \
  10.200.0.30 \
  10.200.0.31 \
  10.200.0.32 \
  10.200.0.33 \
  10.200.0.44 \
  10.200.0.45 \
  10.200.0.46
do
  echo "===== SSH $ip ====="
  ssh -i ~/.ssh/id_ed25519 \
    -o IdentitiesOnly=yes \
    -o StrictHostKeyChecking=no \
    -o ConnectTimeout=5 \
    root@"$ip" "hostname"
done
```

## Ansible Validation Commands

From the DevOps VM:

```bash
cd ansible

ansible-inventory --graph

ansible network_infra -m raw -a "hostname"

ansible-playbook playbooks/site.yml
```

## Manual Validation Commands

### On OVS nodes

```bash
ovs-vsctl show
ip addr
ip route
```

Verify:

- Production interfaces are attached to br0.
- VLAN access/trunk ports are correct.
- OOB interface has 10.200.0.x/24.
- OOB interface is not attached to br0.

### On FRR routers

```bash
ip addr
ip route
vtysh -c "show ip route"
vtysh -c "show ip ospf neighbor"
vtysh -c "show vrrp"
```

Verify:

- OOB interface has 10.200.0.x/24.
- OOB interface is not part of OSPF.
- Production OSPF neighbors are established.
- VRRP gateways are active as expected.

### On DMZ services

```bash
curl http://172.16.50.10
nslookup web.pfe.local 172.16.50.20
```

### On VPCS hosts

```text
show ip
ping <gateway-ip>
```

## Notes

- OOB 10.200.0.0/24 is the primary control path for Ansible/Jenkins.
- VLAN 99 remains an in-band management VLAN inside the production topology.
- OVS bridge configuration must be applied before OVS in-band management IP configuration because mgmt0 depends on br0.
- OOB interfaces must not be added to OVS bridges.
- FRR interface configuration must be applied before validating OSPF, VRRP and routed loopbacks.
- OSPF authentication requires /etc/local/ospf.env inside the FRR containers.
- DMZ-OVS is now managed through OOB IP 10.200.0.33.
- The DevOps VM replaces the earlier WSL-based control-node workflow.