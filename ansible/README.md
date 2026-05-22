# Ansible Automation

This folder contains the Ansible inventory, variables, playbooks and roles used by the dedicated DevOps VM.

## Control Node

Ansible is run from the Ubuntu DevOps VM:

```text
ens33: NAT internet
ens34: 192.168.99.10/24 management/lab interface
```

The DevOps VM must have routes to the lab networks through `192.168.99.1`.

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
| `ovs` | Internal OVS switches plus DMZ-OVS-3 |
| `frr` | FRR routers managed through `10.255.0.x` loopbacks |
| `dmz_services` | Web and DNS health-check targets |
| `vpcs` | Endpoint/test host documentation |
| `network_infra` | SSH-managed OVS + FRR infrastructure |

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

- The playbooks use `raw` for OVS/FRR because Alpine-based containers may not include Python.
- `00_management_readiness.yml` warms up ICMP and waits for TCP/22.
- `00b_wait_for_ansible_connection.yml` verifies that Ansible can actually log in through SSH.
