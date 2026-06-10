# EC2 WireGuard Tunnel Through EdgeRouter-VPNGateway

This directory documents the validated EC2-based hybrid connectivity path between the local GNS3 enterprise lab and the AWS VPC.

The final target architecture places the GNS3 `EdgeRouter-VPNGateway` as the local cloud gateway. The WireGuard tunnel terminates on the EdgeRouter, not on the DevOps VM.

## Final Validated Architecture

```text
Private monitoring EC2
    ↓
AWS private routing
    ↓
AWS EC2 tunnel gateway
    ↓
WireGuard tunnel
    ↓
GNS3 EdgeRouter-VPNGateway
    ↓
Local OOB / GNS3 / DevOps environment
```

Local-to-cloud direction:

```text
DevOps VM / local monitored devices
    ↓
GNS3 EdgeRouter-VPNGateway
    ↓
WireGuard tunnel
    ↓
AWS EC2 tunnel gateway
    ↓
Private monitoring EC2
```

## Why This Design Is Used

The original objective of the platform is to make the EdgeRouter the cloud boundary of the simulated enterprise network.

The DevOps VM must not become the final cloud gateway. DevOps remains the automation and control server. It can provide temporary NAT underlay access in the student lab, but the hybrid cloud gateway role belongs to EdgeRouter-VPNGateway.

This preserves the intended enterprise-style separation:

```text
DevOps VM:
  automation, Jenkins, Ansible, Terraform, local monitoring tools, NAT underlay support

EdgeRouter-VPNGateway:
  border routing, cloud/VPN gateway, WireGuard tunnel termination

AWS EC2 tunnel gateway:
  public cloud-side WireGuard endpoint

Private monitoring EC2:
  private cloud monitoring/observability target
```

## DevOps NAT Underlay vs EdgeRouter Gateway Role

The DevOps NAT underlay and the EdgeRouter gateway role are different responsibilities.

```text
DevOps NAT underlay:
  Provides temporary internet access for EdgeRouter.
  Allows EdgeRouter to reach the AWS EC2 public tunnel endpoint.
  Does not terminate WireGuard.
  Does not act as the cloud gateway.

EdgeRouter-VPNGateway:
  Terminates the local WireGuard tunnel.
  Routes cloud traffic toward AWS.
  Represents the local enterprise cloud boundary.
```

Validated underlay path:

```text
EdgeRouter 10.200.0.30
    ↓
DevOps OOB 10.200.0.10
    ↓
DevOps NAT / VMware internet path
    ↓
AWS public EC2 tunnel gateway UDP/51820
```

Validated encrypted tunnel path:

```text
EdgeRouter wg0 10.255.0.2
    ↓
WireGuard
    ↓
AWS tunnel gateway wg0 10.255.0.1
    ↓
AWS VPC 10.50.0.0/16
    ↓
Private monitoring EC2
```

## Validated Connection

The following tunnel state was successfully validated:

```text
EdgeRouter WireGuard IP:       10.255.0.2/30
AWS tunnel gateway WireGuard:  10.255.0.1/30
AWS VPC CIDR:                  10.50.0.0/16
Private monitoring EC2:        10.50.30.x
```

Successful EdgeRouter tests:

```bash
wg show
ping -c 3 10.255.0.1
ping -c 3 10.50.30.154
```

Expected result:

```text
latest handshake: Now
0% packet loss to 10.255.0.1
0% packet loss to private monitoring EC2
```

This proves:

```text
EdgeRouter-VPNGateway
    -> WireGuard tunnel
AWS EC2 tunnel gateway
    -> private monitoring EC2
```

## Important Debugging Finding

During implementation, EdgeRouter originally tried to reach the AWS public tunnel IP using the wrong path:

```text
13.48.106.15 via 203.0.113.1 dev eth3
```

That route did not work in the lab.

The fix was to route the public tunnel underlay through the DevOps OOB interface:

```text
13.48.106.15 via 10.200.0.10 dev eth4
```

This works because the DevOps VM provides temporary NAT underlay access for EdgeRouter.

The persistent EdgeRouter route is stored in:

```text
frr/routing/edge-router.conf
```

The DevOps NAT underlay helper is stored in:

```text
scripts/devops/enable-edge-router-internet-underlay-nat.sh
```

The old simulated external path through `203.0.113.1` is not used for the validated AWS tunnel.

## MTU and MSS Fix for Nested Tunnel Traffic

During the validation of the EdgeRouter-based tunnel, ICMP connectivity and WireGuard handshake were not enough to guarantee that TCP sessions worked correctly.

The first SSH test from DevOps to the private monitoring EC2 reached the server and started the SSH negotiation, but it stalled during key exchange:

```text
debug1: SSH2_MSG_KEXINIT sent
debug1: SSH2_MSG_KEXINIT received
debug1: expecting SSH2_MSG_KEX_ECDH_REPLY
```

This behavior indicated that the path was reachable at Layer 3, but larger TCP packets were likely being dropped or fragmented across the nested path:

```text
DevOps VM
    -> GNS3 EdgeRouter
    -> WireGuard tunnel
    -> AWS EC2 tunnel gateway
    -> AWS VPC
    -> private monitoring EC2
```

The fix was to set a conservative WireGuard MTU and clamp TCP MSS on both WireGuard edges.

Validated MTU:

```text
MTU = 1280
```

Applied on:

```text
EdgeRouter-VPNGateway wg0
AWS EC2 tunnel gateway wg0
```

The MSS clamp rules are applied in the `mangle` table for forwarded TCP SYN packets:

```text
iptables -t mangle -A FORWARD -o wg0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
iptables -t mangle -A FORWARD -i wg0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
```

After this change, SSH from DevOps to the private monitoring EC2 succeeded through the full path:

```text
DevOps VM
    -> EdgeRouter-VPNGateway
    -> WireGuard
    -> AWS tunnel gateway
    -> private monitoring EC2
```

The fix is versioned in the safe example files:

```text
frr/wireguard/edge-router-wg0.conf.example
cloud/tunnel/edge-router-path/examples/cloud-wg0.conf.example
```

Real `/etc/wireguard/wg0.conf` files must still remain outside Git because they contain private keys.

## DevOps Route Toward AWS Through EdgeRouter

After the tunnel endpoint moved from DevOps to EdgeRouter, the DevOps VM must reach AWS private networks through the EdgeRouter instead of through a local DevOps WireGuard interface.

Runtime route:

```text
10.50.0.0/16 via 10.200.0.30 dev ens34
```

Meaning:

```text
DevOps VM 10.200.0.10
    -> EdgeRouter-VPNGateway 10.200.0.30
    -> WireGuard tunnel
    -> AWS EC2 tunnel gateway
    -> AWS VPC 10.50.0.0/16
```

This route is versioned through the helper script:

```text
scripts/devops/route-cloud-via-edge-router.sh
```

Validation from DevOps:

```bash
cd cloud/terraform/environments/dev

MON_IP="$(terraform output -raw monitoring_private_ip)"

sudo ../../../scripts/devops/route-cloud-via-edge-router.sh

ip route get "$MON_IP"
ssh -o IdentitiesOnly=yes -o IPQoS=none -i ~/.ssh/pfe-aws-tunnel ec2-user@"$MON_IP"
```

Expected route:

```text
10.50.30.x via 10.200.0.30 dev ens34
```

Expected result:

```text
Successful SSH login to the private monitoring EC2 through EdgeRouter.
```

## DevOps NAT Underlay

The DevOps NAT underlay is required only because the local GNS3 lab does not have a stable direct public internet uplink for the EdgeRouter container.

It allows EdgeRouter to reach:

```text
AWS EC2 tunnel gateway public IP
external troubleshooting targets
package repositories when needed
```

However:

```text
DevOps is not the final cloud gateway.
DevOps does not terminate the final WireGuard tunnel.
DevOps only provides temporary NAT/internet underlay.
```

The scripts are:

```text
scripts/devops/enable-edge-router-internet-underlay-nat.sh
scripts/devops/disable-edge-router-internet-underlay-nat.sh
```

## WireGuard Configuration Files

Real WireGuard files must not be committed.

Safe examples are versioned here:

```text
cloud/tunnel/edge-router-path/examples/cloud-wg0.conf.example
frr/wireguard/edge-router-wg0.conf.example
```

Real files are created manually on the nodes:

```text
AWS tunnel gateway:
  /etc/wireguard/wg0.conf

EdgeRouter-VPNGateway:
  /etc/wireguard/wg0.conf
```

Do not commit:

```text
real wg0.conf
WireGuard private keys
SSH private keys
Terraform tfvars
Terraform state files
AWS credentials
GitHub tokens
```

## AWS Side

AWS tunnel gateway:

```text
Address: 10.255.0.1/30
ListenPort: 51820
AllowedIPs for EdgeRouter peer:
  10.255.0.2/32
  10.200.0.0/24
  172.16.0.0/16
```

The AWS tunnel gateway also requires:

```text
net.ipv4.ip_forward = 1
UDP/51820 accepted before INPUT reject rules
wg0 forwarding accepted before FORWARD reject rules
source_dest_check = false on the EC2 instance
routes from private/monitoring route tables toward local CIDRs through the tunnel gateway ENI
```

## EdgeRouter Side

EdgeRouter tunnel endpoint:

```text
Address: 10.255.0.2/30
Peer endpoint: AWS_TUNNEL_PUBLIC_IP:51820
AllowedIPs:
  10.255.0.1/32
  10.50.0.0/16
```

EdgeRouter requires:

```text
wireguard-tools
iptables
tcpdump
IP forwarding
default underlay route through DevOps OOB NAT
```

WireGuard tools are baked into the FRR Docker image instead of being installed manually inside the running container.

## Docker Image

The EdgeRouter uses the custom FRR SSH image from:

```text
docker/frr-ssh/
```

The image includes:

```text
wireguard-tools
iptables
tcpdump
curl
ca-certificates
```

This avoids unreliable runtime `apk update` operations inside recreated GNS3 containers.

## Known Hosts After Container Recreation

When GNS3 Docker containers are recreated, their SSH host keys can change.

This can trigger:

```text
WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!
```

For the controlled OOB lab subnet, refresh known hosts with:

```bash
./scripts/devops/refresh-gns3-known-hosts.sh
```

Do not disable SSH host key checking globally.

## Validation Commands

On DevOps, enable the EdgeRouter internet underlay:

```bash
sudo ./scripts/devops/enable-edge-router-internet-underlay-nat.sh
```

Then validate from DevOps:

```bash
cd cloud/terraform/environments/dev

TGW_PUBLIC_IP="$(terraform output -raw tunnel_gateway_public_ip)"
MON_IP="$(terraform output -raw monitoring_private_ip)"

ssh root@10.200.0.30 "ip route get $TGW_PUBLIC_IP"
ssh root@10.200.0.30 "wg-quick down wg0 2>/dev/null || true; wg-quick up wg0; wg show"
ssh root@10.200.0.30 "ping -c 3 10.255.0.1"
ssh root@10.200.0.30 "ping -c 3 $MON_IP"
```

Expected:

```text
Route to AWS public endpoint uses 10.200.0.10 through eth4.
latest handshake: Now
0% packet loss to AWS tunnel IP
0% packet loss to private monitoring EC2
```

## Current Status

Validated:

```text
AWS tunnel gateway is reachable from EdgeRouter.
WireGuard handshake succeeds between EdgeRouter and AWS.
EdgeRouter can ping AWS tunnel IP 10.255.0.1.
EdgeRouter can ping private monitoring EC2.
DevOps direct WireGuard tunnel has been disabled.
DevOps NAT underlay is used only for EdgeRouter public endpoint reachability.
```
