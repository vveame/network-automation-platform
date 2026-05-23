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

## Run Order

From the DevOps VM:

```bash
cd ansible
ansible-inventory --list
ansible-playbook playbooks/site.yml
```

The main site playbook runs readiness checks first, then validates OVS, FRR, DMZ services, security rules and end-to-end connectivity.

## Output Files

Validation reports are written to:

```text
ansible/outputs/
```

## Notes

- The playbooks use raw for OVS/FRR because Alpine-based containers may not include Python.
- `00_management_readiness.yml` verifies OOB reachability to infrastructure nodes.
- `00b_wait_for_ansible_connection.yml` verifies that Ansible can log in through SSH.
- The production topology remains the validation target, while the OOB network is the automation control path.