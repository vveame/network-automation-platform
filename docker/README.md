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
| `pfe/frr-ssh:latest` | FRRouting router image with SSH, FRR startup automation, OSPF and VRRP support |
| `pfe/ovs-ssh:latest` | Open vSwitch image with SSH, OVS startup automation and management access |

## FRR Image

The FRR image is used for:

- Dist-FRR-1
- Dist-FRR-2
- Core-FRR-1
- Core-FRR-2
- EdgeRouter-VPNGateway

At startup, the FRR container:

1. Initializes `/etc/frr` if required.
2. Enables FRR daemons such as `zebra`, `ospfd` and `vrrpd`.
3. Loads the router environment file if present.
4. Applies the Linux interface configuration from `/etc/local/interfaces.sh`.
5. Starts FRR daemons.
6. Applies OSPF authentication if the script and secret file are present.
7. Applies role-specific security rules depending on the router role.
8. Applies SSH/admin access restriction.
9. Starts the SSH daemon for DevOps automation.

## OVS Image

The OVS image is used for:

- Access-OVS-4
- Access-OVS-5
- Access-OVS-6
- Dist-OVS-1
- Dist-OVS-2

At startup, the OVS container:

1. Starts Open vSwitch services.
2. Applies the bridge, VLAN and trunk configuration from `/etc/local/ovs-config.sh`.
3. Applies the management IP configuration from `/etc/local/ovs-mgmt.sh`.
4. Applies SSH/admin access restriction.
5. Starts the SSH daemon for DevOps automation.

## Build Commands

Run from the repository root:

```bash
docker build -t pfe/frr-ssh:latest docker/frr-ssh/
docker build -t pfe/ovs-ssh:latest docker/ovs-ssh/
```

## Expected Local Files in FRR Containers

Each FRR container should receive the correct node-specific files:

```bash
/etc/local/router.env
/etc/local/interfaces.sh
/etc/frr/frr.conf
/etc/local/security/admin-access-control.sh
/etc/local/security/ospf-auth.sh
/etc/local/ospf.env
```

Distribution routers also use:

```bash
/etc/local/security/management-vlan-protection.sh
```

The EdgeRouter also uses:

```bash
/etc/local/security/dmz-isolation.sh
/etc/local/security/nat-control.sh
```

## Expected Local Files in OVS Containers

Each OVS container should receive:

```bash
/etc/local/ovs-config.sh
/etc/local/ovs-mgmt.sh
/etc/local/security/admin-access-control.sh
```

The content of these files differs per node, but the local filenames stay the same.
For example:

```bash
ovs/access/access-ovs-4.sh              -> /etc/local/ovs-config.sh
ovs/management/access-ovs-4-mgmt.sh     -> /etc/local/ovs-mgmt.sh
```