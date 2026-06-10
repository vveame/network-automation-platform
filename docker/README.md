# Docker Images

This folder contains the custom Docker images used by the GNS3 topology.

## Purpose

The default FRRouting and Open vSwitch containers do not necessarily include SSH, startup automation, OOB management support or the extra tooling required for the project.

For Jenkins and Ansible automation, the infrastructure nodes must be reachable remotely from the DevOps server through the OOB management plane.

This folder defines custom Docker images that provide:

```text
SSH access for automation
startup scripts for applying local configuration files
OOB management interface support
root key-only SSH preparation
FRR daemon initialization
Open vSwitch service initialization
support for versioned configuration deployment
WireGuard tooling for EdgeRouter-VPNGateway
```

## Images

| Image                        | Purpose                                                                                             |
| ---------------------------- | --------------------------------------------------------------------------------------------------- |
| `vviam/pfe-frr-ssh:latest`   | FRRouting router image with SSH, FRR startup automation, OOB management support and WireGuard tools |
| `vviam/pfe-ovs-ssh:latest`   | Open vSwitch image with SSH, OVS startup automation and OOB management support                      |
| `vviam/pfe-web-nginx:latest` | DMZ Web server image running Nginx                                                                  |
| `vviam/pfe-dns:latest`       | DMZ DNS server image running BIND for `pfe.local`                                                   |

## FRR Image

The FRR image is used for:

```text
Dist-FRR-1
Dist-FRR-2
Core-FRR-1
Core-FRR-2
EdgeRouter-VPNGateway
```

At startup, the FRR container:

```text
1. Loads /etc/local/router.env if present.
2. Sets the Linux hostname.
3. Enables FRR daemons such as zebra, ospfd, staticd and vrrpd.
4. Applies the Linux production interface configuration from /etc/local/interfaces.sh.
5. Applies OOB management interface configuration from /etc/local/oob-mgmt.sh.
6. Starts FRR daemons.
7. Applies OSPF authentication if /etc/local/ospf.env exists.
8. Applies role-specific security scripts.
9. Applies SSH/admin access restriction.
10. Ensures root can use key-only SSH.
11. Starts SSH for Ansible access.
```

FRR OOB interfaces must not participate in OSPF.

## EdgeRouter WireGuard Support

The `vviam/pfe-frr-ssh` image is also used by `EdgeRouter-VPNGateway`.

For the validated hybrid cloud path, the local side of the WireGuard tunnel terminates directly on `EdgeRouter-VPNGateway`.

WireGuard tools are baked directly into the FRR image instead of being installed manually inside a running GNS3 container. This avoids runtime `apk update` failures inside the lab topology.

The FRR image includes:

```text
wireguard-tools
iptables
tcpdump
curl
ca-certificates
```

This allows EdgeRouter to run:

```text
wg
wg-quick
iptables
tcpdump
curl
```

The real WireGuard configuration must not be committed. Only safe examples are versioned:

```text
frr/wireguard/edge-router-wg0.conf.example
cloud/tunnel/edge-router-path/examples/cloud-wg0.conf.example
```

Target architecture:

```text
Private monitoring EC2
    -> AWS EC2 tunnel gateway
    -> WireGuard tunnel
    -> EdgeRouter-VPNGateway
    -> local OOB / GNS3 / DevOps environment
```

The DevOps VM may provide NAT underlay access for EdgeRouter, but it does not terminate the tunnel.

## OVS Image

The OVS image is used for:

```text
Access-OVS-4
Access-OVS-5
Access-OVS-6
Dist-OVS-1
Dist-OVS-2
DMZ-OVS-3
```

At startup, the OVS container:

```text
1. Starts Open vSwitch services.
2. Applies the bridge, VLAN and trunk configuration from /etc/local/ovs-config.sh.
3. Applies the in-band management configuration from /etc/local/ovs-mgmt.sh if present.
4. Applies OOB management interface configuration from /etc/local/oob-mgmt.sh.
5. Applies SSH/admin access restriction.
6. Ensures root can use key-only SSH.
7. Starts SSH for Ansible access.
```

The OOB interface on OVS nodes must not be added to `br0`.

Internal OVS nodes keep VLAN 99 `mgmt0` addresses as in-band management addresses, but Ansible and Jenkins use the OOB IPs in `10.200.0.0/24`.

## Web and DNS Images

The Web and DNS containers are service nodes, not SSH-managed infrastructure nodes.

| Service | IP             | Validation method                     |
| ------- | -------------- | ------------------------------------- |
| Web     | `172.16.50.10` | `curl http://172.16.50.10`            |
| DNS     | `172.16.50.20` | `nslookup web.pfe.local 172.16.50.20` |

The host IP scripts are copied into `/opt/pfe/host-ip.sh` inside the service images so GNS3 persistent directories do not hide them.

## Build Commands

Run from the repository root on the GNS3 host:

```bash
docker build -t vviam/pfe-frr-ssh:latest docker/frr-ssh/
docker build -t vviam/pfe-ovs-ssh:latest docker/ovs-ssh/
docker build -f docker/web-nginx/Dockerfile -t vviam/pfe-web-nginx:latest .
docker build -f docker/dns/Dockerfile -t vviam/pfe-dns:latest .
```

Verify the FRR image contains WireGuard tools:

```bash
docker run --rm vviam/pfe-frr-ssh:latest sh -lc 'wg --version && command -v wg-quick && iptables --version && tcpdump --version | head -n 1'
```

Expected result:

```text
wireguard-tools is installed
wg-quick exists
iptables is available
tcpdump is available
```

## Expected Files in FRR Containers

```text
/etc/local/router.env
/etc/local/interfaces.sh
/etc/local/oob-mgmt.sh
/etc/local/oob-mgmt.env
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
```

The legacy script below may exist in the repository but should not be automatically enabled for the validated EdgeRouter WireGuard path:

```text
/etc/local/security/nat-control.sh
```

The validated EdgeRouter AWS tunnel does not use the old `203.0.113.1` default route. EdgeRouter reaches the AWS public tunnel endpoint through the DevOps NAT underlay.

## Expected Local Files in OVS Containers

Each OVS container should receive:

```text
/etc/local/ovs-config.sh
/etc/local/ovs-mgmt.sh
/etc/local/oob-mgmt.sh
/etc/local/oob-mgmt.env
/etc/local/security/admin-access-control.sh
```

## Expected OOB Behavior

Managed infrastructure nodes should expose SSH on their OOB IPs:

| Node family  | OOB subnet      |
| ------------ | --------------- |
| FRR routers  | `10.200.0.0/24` |
| OVS switches | `10.200.0.0/24` |
| DMZ-OVS-3    | `10.200.0.0/24` |

The DevOps server uses `10.200.0.10` as the only allowed SSH administrative source.
