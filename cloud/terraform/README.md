# Terraform Cloud Baseline

This directory contains the Terraform configuration for the AWS cloud part of the intelligent network automation platform.

The Terraform code provisions the AWS infrastructure used by the project for:

```text
cloud networking
security groups
artifact storage
optional compute
EC2-based hybrid tunnel
future monitoring services
future AI/anomaly-analysis services
future VPN extension
```

## Objective

The cloud baseline prepares the AWS environment that integrates with the local GNS3/DevOps platform.

The local infrastructure is implemented in GNS3 and validated through Jenkins and Ansible. The AWS environment provides the cloud side for artifact storage, hybrid connectivity, future monitoring services and future anomaly-analysis services.

Terraform is used to keep the AWS infrastructure:

```text
reproducible
versioned
cost-aware
modular
safe to enable progressively
```

## Current Implementation Status

The current Terraform baseline implements:

```text
AWS VPC
public subnet
private subnet
monitoring / AI subnet
Internet Gateway
public route table
private route table
monitoring route table
route table associations
security group baseline
private S3 artifacts bucket
S3 public access blocking
S3 ownership controls
S3 versioning
S3 server-side encryption
S3 lifecycle rules
optional EC2 tunnel gateway
optional private monitoring EC2
optional private AI EC2 placeholder
SSM IAM instance profile for EC2 administration
disabled AWS Site-to-Site VPN module
```

The EC2-based WireGuard tunnel option has been implemented and validated with the GNS3 `EdgeRouter-VPNGateway` as the local tunnel endpoint.

Validated EC2 tunnel resources:

```text
public EC2 tunnel gateway
private monitoring EC2 instance
WireGuard tunnel between EdgeRouter-VPNGateway and AWS tunnel gateway
route table entries toward local/on-premises CIDRs
source_dest_check disabled on the tunnel gateway
user-data preparation for iptables, WireGuard tools and IP forwarding
```

The AWS managed Site-to-Site VPN module remains disabled. No NAT Gateway is created in order to avoid unnecessary AWS cost during the student lab phase.

## Directory Structure

```text
cloud/terraform/
├── environments/
│   └── dev/
│       ├── versions.tf
│       ├── providers.tf
│       ├── locals.tf
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars.example
├── modules/
│   ├── network/
│   ├── security/
│   ├── compute/
│   │   └── user-data/
│   ├── storage/
│   └── vpn/
└── README.md
```

Additional tunnel documentation is stored in:

```text
cloud/tunnel/edge-router-path/
```

## Environment

The current environment is:

```text
cloud/terraform/environments/dev
```

It represents the first development cloud environment for the PFE lab.

The default cloud CIDR plan is:

```text
VPC CIDR: 10.50.0.0/16
Public subnet: 10.50.10.0/24
Private subnet: 10.50.20.0/24
Monitoring/AI subnet: 10.50.30.0/24
WireGuard tunnel: 10.255.0.0/30
```

## Modules

### network

Implemented.

Creates the AWS networking baseline:

```text
VPC
public subnet
private subnet
monitoring / AI subnet
Internet Gateway
public route table
private route table
monitoring route table
route table associations
```

Only the public subnet has a default route to the Internet Gateway.

The private and monitoring subnets remain private. When the EC2 tunnel option is enabled, Terraform adds routes from the private/monitoring route tables toward the local CIDRs through the tunnel gateway network interface.

### security

Implemented.

Creates the AWS security group baseline:

```text
tunnel gateway / admin security group
monitoring security group
AI analysis security group
private services security group
standalone ingress rules
standalone egress rules
```

Security group rules are managed as standalone Terraform resources instead of inline security group rules. This keeps rule management clearer and avoids conflicts between inline and standalone rule definitions.

The security module separates:

```text
SSH access
WireGuard UDP access
monitoring access
private service access
```

Important variables:

```hcl
admin_allowed_cidr     = "YOUR_CURRENT_PUBLIC_IP/32"
wireguard_allowed_cidr = "0.0.0.0/0"
```

`admin_allowed_cidr` controls SSH access to the public tunnel gateway.

`wireguard_allowed_cidr` controls UDP WireGuard access. Because the local public IP can change frequently, WireGuard UDP can be allowed from `0.0.0.0/0` while still requiring valid peer keys.

SSH must remain restrictive and should not stay open to `0.0.0.0/0`.

### storage

Implemented.

Creates the AWS storage baseline:

```text
private S3 artifacts bucket
public access block
bucket owner enforced ownership controls
versioning
server-side encryption
lifecycle retention rules
```

The storage bucket is reserved for:

```text
validation reports
metrics exports
analyzer outputs
ML datasets and decisions
remediation plans and reports
future logs
future datasets
future AI outputs
```

The S3 bucket is not used for Terraform remote state at this stage.

Terraform state remains local during the current development phase.

### compute

Implemented as an optional module.

The compute module is disabled by default in example configuration files in order to avoid unnecessary AWS costs.

Preferred separate switches:

```hcl
enable_tunnel_gateway      = false
enable_monitoring_instance = false
enable_ai_instance         = false
```

For the validated development environment, the local uncommitted `terraform.tfvars` can enable:

```hcl
enable_tunnel_gateway      = true
enable_monitoring_instance = true
enable_ai_instance         = false
```

When enabled, the compute module can create:

```text
public EC2 tunnel gateway
private monitoring EC2 instance
optional private AI EC2 instance
EC2 key pair if a public SSH key is provided
SSM IAM role and instance profile
```

The EC2 tunnel gateway has:

```text
public IP
source_dest_check = false
WireGuard tooling prepared by user-data
IP forwarding enabled
iptables rules prepared for WireGuard and AWS VPC forwarding
optional NAT/routing behavior for the monitoring subnet
```

The monitoring EC2 has:

```text
no public IP
private IP in the monitoring subnet
SSH access through the tunnel path
future Prometheus/Grafana role
```

### vpn

Implemented as a disabled hybrid connectivity module.

The VPN module remains disabled by default:

```hcl
enable_vpn = false
```

When enabled in the future, it can create:

```text
AWS Customer Gateway
AWS Virtual Private Gateway
AWS Site-to-Site VPN connection
static VPN routes
VPC route table routes toward on-premises CIDRs
```

At the current stage, the managed AWS VPN is not used because the student lab does not have a stable public local endpoint and because the managed VPN adds cost and complexity.

## EC2-Based Hybrid Tunnel Design

The current hybrid implementation uses an EC2-based WireGuard tunnel instead of AWS managed Site-to-Site VPN.

Validated target architecture:

```text
Local GNS3 / DevOps environment
    ↓
EdgeRouter-VPNGateway
    ↓
WireGuard tunnel
    ↓
Public EC2 tunnel gateway
    ↓
Private monitoring EC2
```

The local WireGuard endpoint runs on the GNS3 `EdgeRouter-VPNGateway`, not on the DevOps VM.

The DevOps VM provides a temporary NAT-based internet underlay only because the GNS3 EdgeRouter does not have a direct working public internet uplink in the student lab.

This underlay is required for EdgeRouter to reach the AWS public tunnel endpoint over UDP/51820.

DevOps remains the automation server and does not act as the final cloud gateway.

## EC2 Tunnel Variables

The validated tunnel phase is enabled locally with:

```hcl
enable_compute             = false
enable_tunnel_gateway      = true
enable_monitoring_instance = true
enable_ai_instance         = false
enable_vpn                 = false
```

WireGuard settings:

```hcl
wireguard_tunnel_cidr = "10.255.0.0/30"
wireguard_port        = 51820
```

Local/on-premises CIDRs routed through the tunnel:

```hcl
onprem_cidr_blocks = [
  "10.200.0.0/24",
  "172.16.0.0/16"
]
```

Access CIDRs:

```hcl
admin_allowed_cidr     = "YOUR_CURRENT_PUBLIC_IP/32"
wireguard_allowed_cidr = "0.0.0.0/0"
```

The local public IP was observed to change frequently. For that reason, SSH and WireGuard access are controlled separately.

Temporary debugging only:

```hcl
admin_allowed_cidr = "0.0.0.0/0"
```

This must be reverted after debugging.

## User-Data Templates

The compute module uses Terraform user-data templates stored in:

```text
cloud/terraform/modules/compute/user-data/
```

Current templates:

```text
tunnel-gateway.sh.tftpl
monitoring.sh.tftpl
```

These files are important and must be committed because they make EC2 rebuilds reproducible.

The tunnel gateway user-data prepares the public EC2 instance by:

```text
setting the hostname
enabling IPv4 forwarding
installing WireGuard tools
installing iptables services
installing tcpdump for troubleshooting
allowing SSH before default reject rules
allowing WireGuard UDP before default reject rules
allowing wg0 forwarding before default reject rules
allowing established/related forwarded traffic
allowing AWS VPC traffic back toward wg0
configuring optional NAT for the monitoring subnet
preparing /etc/wireguard
creating an instance-local README
```

The monitoring user-data prepares the private monitoring EC2 placeholder.

The user-data files must not contain:

```text
real SSH private keys
real WireGuard private keys
real wg0.conf files
AWS credentials
GitHub tokens
passwords
```

Only generic scripts and safe placeholders are stored in the repository.

## WireGuard Configuration

WireGuard private keys are created manually on the EdgeRouter and on the AWS tunnel gateway.

Safe example files are stored in:

```text
cloud/tunnel/edge-router-path/examples/cloud-wg0.conf.example
frr/wireguard/edge-router-wg0.conf.example
```

The real files are created outside the repository:

```text
AWS tunnel gateway:
  /etc/wireguard/wg0.conf
  /etc/wireguard/cloud_private.key

EdgeRouter-VPNGateway:
  /etc/wireguard/wg0.conf
  /etc/wireguard/edge_private.key
```

Do not commit real WireGuard configuration files.

AWS tunnel gateway:

```text
WireGuard IP: 10.255.0.1/30
Listen port: 51820/udp
```

EdgeRouter local tunnel endpoint:

```text
WireGuard IP: 10.255.0.2/30
Peer endpoint: AWS_PUBLIC_TUNNEL_IP:51820
```

EdgeRouter allowed IPs:

```text
10.255.0.1/32
10.50.0.0/16
```

AWS allowed IPs for the EdgeRouter peer:

```text
10.255.0.2/32
10.200.0.0/24
172.16.0.0/16
```

## DevOps NAT Underlay for EdgeRouter

The DevOps NAT underlay is required because the GNS3 EdgeRouter container does not have a direct working public internet uplink in the student lab.

Validated underlay path:

```text
EdgeRouter 10.200.0.30
    ↓
DevOps OOB 10.200.0.10
    ↓
DevOps NAT / VMware internet
    ↓
AWS EC2 public tunnel gateway UDP/51820
```

The helper scripts are stored in:

```text
scripts/devops/enable-edge-router-internet-underlay-nat.sh
scripts/devops/disable-edge-router-internet-underlay-nat.sh
```

This underlay is not the cloud gateway. It is only the internet path required for EdgeRouter to reach the public AWS tunnel endpoint.

## Validated Tunnel Connection

The EC2-based hybrid tunnel has been validated with EdgeRouter as the local endpoint.

Validated commands from EdgeRouter:

```bash
wg show
ping -c 3 10.255.0.1
ping -c 3 10.50.30.154
```

Expected result:

```text
latest handshake visible
0% packet loss to AWS tunnel IP
0% packet loss to private monitoring EC2
```

From DevOps, the validation can be executed as:

```bash
cd cloud/terraform/environments/dev

TGW_PUBLIC_IP="$(terraform output -raw tunnel_gateway_public_ip)"
MON_IP="$(terraform output -raw monitoring_private_ip)"

ssh root@10.200.0.30 "ip route get $TGW_PUBLIC_IP"
ssh root@10.200.0.30 "wg show"
ssh root@10.200.0.30 "ping -c 3 10.255.0.1"
ssh root@10.200.0.30 "ping -c 3 $MON_IP"
```

Expected route:

```text
via 10.200.0.10 dev eth4
```

## Debugging Notes Captured in Code

The first EdgeRouter tunnel test failed because EdgeRouter tried to reach the AWS public tunnel gateway through the old simulated external path:

```text
13.48.106.15 via 203.0.113.1 dev eth3
```

That route did not work in the lab.

The validated fix is:

```text
13.48.106.15 via 10.200.0.10 dev eth4
```

The DevOps VM then performs NAT toward its internet-facing interface.

This behavior is versioned in:

```text
frr/routing/edge-router.conf
scripts/devops/enable-edge-router-internet-underlay-nat.sh
```

The old `203.0.113.2/30` address may remain as a legacy simulated external-link placeholder, but the old default route through `203.0.113.1` must not be used for the validated AWS tunnel.

## Security and Cost Notes

The current implementation avoids AWS NAT Gateway to reduce cost.

The private monitoring EC2 remains private and is reached only through the tunnel path.

Security controls:

```text
SSH access restricted through admin_allowed_cidr.
WireGuard UDP access controlled separately through wireguard_allowed_cidr.
WireGuard peer authentication required through public/private key pairs.
Private monitoring EC2 has no public IP.
Tunnel gateway source_dest_check disabled only where routing requires it.
```

Do not keep public SSH open to:

```text
0.0.0.0/0
```

Use it only temporarily during debugging.

## Files Not to Commit

Do not commit:

```text
terraform.tfvars
terraform.tfstate
terraform.tfstate.backup
tfplan
*.tfplan
.terraform/
real wg0.conf files
WireGuard private keys
SSH private keys
AWS credentials
GitHub tokens
```

Safe files to commit:

```text
Terraform modules
variable definitions
outputs
example tfvars
user-data templates
safe WireGuard examples
README files
scripts without secrets
```

## Current Status

Validated:

```text
VPC baseline exists.
S3 artifact bucket exists.
EC2 tunnel gateway exists.
Private monitoring EC2 exists.
AWS managed Site-to-Site VPN remains disabled.
WireGuard tunnel succeeds between EdgeRouter and AWS tunnel gateway.
EdgeRouter can ping AWS tunnel IP 10.255.0.1.
EdgeRouter can ping private monitoring EC2.
DevOps direct WireGuard tunnel is disabled.
DevOps NAT underlay is used only for EdgeRouter public endpoint reachability.
```

Next steps:

```text
1. Rotate exposed EdgeRouter WireGuard keys if any private key appeared in logs.
2. Route DevOps cloud traffic through EdgeRouter.
3. Deploy Prometheus/Grafana on the private monitoring EC2.
4. Configure cloud monitoring to scrape selected local exporters through the EdgeRouter tunnel.
5. Keep remediation execution controlled locally by Jenkins/Ansible.
```
