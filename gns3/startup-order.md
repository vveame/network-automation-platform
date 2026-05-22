# GNS3 Startup and Validation Order

This file defines the recommended order for starting and validating the local GNS3 topology.

## Startup Order

1. Start the GNS3 VM.
2. Start OVS nodes.
3. Start FRR routers.
4. Start DMZ service nodes: Web and DNS.
5. Start VPCS endpoint hosts.
6. Start or verify the dedicated DevOps VM.
7. Run the persistent bootstrap when containers may be stopped/exited.
8. Run the running bootstrap when all containers are already running and immediate application is required.
9. Run the node-side announce or Ansible management readiness playbook.
10. Run Ansible validation from the DevOps VM.

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
ip -br addr
ip route
./scripts/devops-warmup.sh
cd ansible
ansible-playbook playbooks/site.yml
```

## Manual Validation Commands

### On OVS nodes

```bash
ovs-vsctl show
ip addr
ip route
```

### On FRR routers

```bash
ip addr
ip route
vtysh -c "show ip route"
vtysh -c "show ip ospf neighbor"
vtysh -c "show vrrp"
```

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

- OVS bridge configuration must be applied before OVS management IP configuration because `mgmt0` depends on `br0`.
- FRR interface configuration must be applied before validating OSPF, VRRP and routed loopbacks.
- OSPF authentication requires `/etc/local/ospf.env` inside the FRR containers.
- DMZ-OVS is managed through `172.16.50.3` via EdgeRouter; it is not connected directly to VLAN 99.
- The DevOps VM replaces the earlier WSL-based control-node workflow.
