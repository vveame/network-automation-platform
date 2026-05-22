# Docker Images

This folder contains the custom Docker images used by the GNS3 topology.

## Purpose

The default FRRouting and Open vSwitch containers do not necessarily include SSH or startup automation.  
For Jenkins and Ansible automation, the infrastructure nodes must be reachable remotely from the DevOps server.

This folder defines custom Docker images that provide:

- SSH access for automation.
- Startup scripts for applying local configuration files.
- FRR daemon initialization.
- Open vSwitch service initialization.
- Support for versioned configuration deployment.

## Images

| Image | Purpose |
|---|---|
| `vviam/pfe-frr-ssh:latest` | FRRouting router image with SSH and FRR startup automation |
| `vviam/pfe-ovs-ssh:latest` | Open vSwitch image with SSH, OVS startup automation and management access |
| `vviam/pfe-web-nginx:latest` | DMZ Web server image running Nginx |
| `vviam/pfe-dns:latest` | DMZ DNS server image running BIND for `pfe.local` |

## FRR Image

The FRR image is used for:

- `Dist-FRR-1`
- `Dist-FRR-2`
- `Core-FRR-1`
- `Core-FRR-2`
- `EdgeRouter-VPNGateway`

At startup, the FRR container:

1. Loads `/etc/local/router.env` if present.
2. Sets the Linux hostname.
3. Enables FRR daemons such as `zebra`, `ospfd`, `staticd` and `vrrpd`.
4. Applies the Linux interface configuration from `/etc/local/interfaces.sh`.
5. Starts FRR daemons.
6. Applies OSPF authentication if `/etc/local/ospf.env` exists.
7. Applies role-specific security scripts.
8. Applies SSH/admin access restriction.
9. Starts SSH for Ansible access.

## OVS Image

The OVS image is used for:

- `Access-OVS-4`
- `Access-OVS-5`
- `Access-OVS-6`
- `Dist-OVS-1`
- `Dist-OVS-2`
- `DMZ-OVS-3`

At startup, the OVS container:

1. Starts Open vSwitch services.
2. Applies the bridge, VLAN and trunk configuration from `/etc/local/ovs-config.sh`.
3. Applies the management IP configuration from `/etc/local/ovs-mgmt.sh`.
4. Applies SSH/admin access restriction.
5. Starts SSH for Ansible access.

Internal OVS nodes use VLAN 99 management IPs. `DMZ-OVS-3` uses `172.16.50.3/24` inside the DMZ and is reached through EdgeRouter firewall rules.

## Web and DNS Images

The Web and DNS containers are service nodes, not SSH-managed infrastructure nodes.

| Service | IP | Validation method |
|---|---|---|
| Web | `172.16.50.10` | `curl http://172.16.50.10` |
| DNS | `172.16.50.20` | `nslookup web.pfe.local 172.16.50.20` |

The host IP scripts are copied into `/opt/pfe/host-ip.sh` inside the service images so GNS3 persistent directories do not hide them.

## Build Commands

Run from the repository root:

```bash
docker build -t vviam/pfe-frr-ssh:latest docker/frr-ssh/
docker build -t vviam/pfe-ovs-ssh:latest docker/ovs-ssh/
docker build -f docker/web-nginx/Dockerfile -t vviam/pfe-web-nginx:latest .
docker build -f docker/dns/Dockerfile -t vviam/pfe-dns:latest .
```

## Expected Files in FRR Containers

```text
/etc/local/router.env
/etc/local/interfaces.sh
/etc/frr/frr.conf
/etc/local/security/admin-access-control.sh
/etc/local/security/ospf-auth.sh
/etc/local/ospf.env
```

Distribution routers also use:

```text
/etc/local/security/management-vlan-protection.sh
```

The EdgeRouter also uses:

```text
/etc/local/security/dmz-isolation.sh
/etc/local/security/nat-control.sh
```

## Expected Local Files in OVS Containers

Each OVS container should receive:

```text
/etc/local/ovs-config.sh
/etc/local/ovs-mgmt.sh
/etc/local/security/admin-access-control.sh
```