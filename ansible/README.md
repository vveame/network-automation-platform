# Ansible Automation

This folder contains the Ansible inventory, variables, playbooks and roles used by the dedicated DevOps VM.

## Control Node

Ansible is run from the Ubuntu DevOps VM:

```text
ens33: NAT internet
ens34: 10.200.0.10/24 OOB management interface
```

The DevOps VM uses the OOB network for SSH access to infrastructure nodes.

The DevOps VM does not need the production topology to be healthy in order to access managed infrastructure nodes.

## Node Policy

```text
Network infrastructure nodes:
  SSH required and validated by Ansible

Service nodes:
  SSH not required; validated through health checks

Endpoint/test hosts:
  SSH not required; validated through connectivity tests
```

The validation model follows a strict rule: infrastructure nodes are managed by SSH over OOB, service nodes are validated by health checks, and endpoint/test hosts are documented or validated through connectivity tests.

## Inventory Groups

| Group | Purpose |
|---|---|
| `ovs` | OVS infrastructure nodes managed through OOB IPs |
| `frr` | FRR routers managed through OOB IPs |
| `dmz_services` | Web and DNS health-check targets |
| `vpcs` | Endpoint/test host documentation |
| `network_infra` | SSH-managed OVS + FRR infrastructure |

## Management Addressing

Ansible uses the OOB management plane for infrastructure access.

| Node | Ansible management IP |
|---|---|
| Core-FRR-1 | `10.200.0.11` |
| Core-FRR-2 | `10.200.0.12` |
| Dist-FRR-1 | `10.200.0.21` |
| Dist-FRR-2 | `10.200.0.22` |
| EdgeRouter-VPNGateway | `10.200.0.30` |
| Dist-OVS-1 | `10.200.0.31` |
| Dist-OVS-2 | `10.200.0.32` |
| DMZ-OVS-3 | `10.200.0.33` |
| Access-OVS-4 | `10.200.0.44` |
| Access-OVS-5 | `10.200.0.45` |
| Access-OVS-6 | `10.200.0.46` |

FRR loopbacks 10.255.0.0/24 remain validation targets, not the primary Ansible SSH path.

VLAN 99 remains an in-band management VLAN, not the primary Ansible SSH path.

## Validation Scope

The platform separates the automation control path from the production data path.

```text
OOB management plane:
  Used by DevOps, Ansible and future Jenkins for SSH and validation control

Production/data plane:
  Contains VLANs, OSPF, VRRP, DMZ, NAT and firewall behavior

Dashboard/reporting layer:
  Consumes Ansible output files and displays validation results
```

The DevOps VM does not directly validate all production VLAN gateways from its OOB interface. Production gateways and FRR loopbacks are validated through the FRR validation role using interface, routing, OSPF and VRRP checks.

The end-to-end playbook validates only what the DevOps VM is expected to reach from the OOB/control side:

```text
OOB SSH to infrastructure nodes
DMZ Web HTTP health check
DMZ DNS resolution check
```

## SSH Requirements

The managed infrastructure nodes must allow key-only SSH from:

```text
10.200.0.10
```

The inventory should use:

```text
ansible_user=root
ansible_ssh_private_key_file=~/.ssh/id_ed25519
ansible_ssh_common_args='-o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5'
```

## OOB-to-DMZ Security Policy

The DevOps VM may reach DMZ services only for explicit validation purposes.

Allowed from the DevOps OOB IP:

```text
10.200.0.10 -> 172.16.50.10 TCP/80
10.200.0.10 -> 172.16.50.20 UDP/53
10.200.0.10 -> 172.16.50.20 TCP/53
```

Blocked examples:

```text
10.200.0.10 -> 172.16.50.10 TCP/22
10.200.0.10 -> 172.16.50.20 TCP/80
10.200.0.10 -> 172.16.50.20 TCP/22
```

This keeps the OOB network as a controlled management and validation plane instead of an unrestricted path into the DMZ.

## Run Order

From the DevOps VM:

```bash
cd ansible
ansible-inventory --graph
ansible-playbook --syntax-check playbooks/site.yml
ansible-playbook playbooks/site.yml
```

The main site playbook is designed as a Jenkins-ready validation gate. It runs the validation sequence in this order:

```text
06_validate_inventory_consistency.yml
00_management_readiness.yml
00b_wait_for_ansible_connection.yml
01_validate_ovs.yml
02_validate_frr.yml
03_validate_dmz_services.yml
04_validate_security_rules.yml
05_validate_end_to_end.yml
07_validate_report_artifacts.yml
report_collect
```

This order ensures that variable consistency, OOB reachability and SSH readiness are validated before testing the production topology, security rules, end-to-end behavior and generated report artifacts.

## Jenkins-Ready Validation Gates

The Ansible workflow is not limited to report collection. It now acts as a validation gate that can fail a future Jenkins pipeline if an expected state is not respected.

The validation gates include:

| Validation area | Purpose |
|---|---|
| Inventory consistency | Ensures required variables exist, OOB IPs are unique, expected nodes exist in inventory and `ansible_host` matches the expected OOB IP |
| OOB readiness | Verifies that the DevOps VM can reach infrastructure nodes through the OOB management network |
| Ansible SSH readiness | Confirms that key-based SSH works before running infrastructure validation |
| OVS validation | Checks OVS bridge existence, OOB interface isolation, RSTP state, access VLAN tags and trunk VLANs |
| FRR validation | Checks OOB interfaces, loopbacks, OSPF FULL neighbor count, VRRP virtual gateways and firewall/NAT state |
| DMZ services | Validates Web HTTP access and DNS resolution |
| Security validation | Confirms allowed flows and asserts that unwanted services such as Web SSH, DNS HTTP and DNS SSH are blocked |
| End-to-end validation | Validates OOB-managed access and controlled DMZ health checks from the DevOps VM |
| Report artifact validation | Ensures that all expected validation output files are generated and not empty |

If one of these checks fails, the playbook fails. This behavior prepares the platform for Jenkins CI/CD integration.

## Output Files

Validation reports are written to:

```text
ansible/outputs/
```

Expected output files include:

```text
inventory-consistency.txt
oob-management-readiness.txt
security-validation.txt
end-to-end-validation.txt
report-artifacts-validation.txt
validation-summary.txt
dmz-services.txt

core-frr-1-frr.txt
core-frr-2-frr.txt
dist-frr-1-frr.txt
dist-frr-2-frr.txt
edge-router-frr.txt

access-ovs-4-ovs.txt
access-ovs-5-ovs.txt
access-ovs-6-ovs.txt
dist-ovs-1-ovs.txt
dist-ovs-2-ovs.txt
dmz-ovs-3-ovs.txt
```

These reports are consumed by the Flask validation dashboard microservice and can later be archived by Jenkins as pipeline artifacts.

## Notes

- The playbooks use `raw` for OVS and FRR validation because the container images may not include Python.
- `00_management_readiness.yml` verifies OOB reachability to infrastructure nodes.
- `00b_wait_for_ansible_connection.yml` verifies that Ansible can log in through SSH.
- `06_validate_inventory_consistency.yml` validates variables, inventory membership and OOB addressing before infrastructure checks run.
- `07_validate_report_artifacts.yml` ensures expected reports are generated and not empty.
- VLAN 99 and FRR loopbacks remain production validation targets, not the primary Ansible SSH path.
- The production topology remains the validation target, while the OOB network is the automation control path.
- The end-to-end playbook does not force the DevOps VM to behave like a production VLAN endpoint.
- Security validation asserts both allowed flows and blocked flows.