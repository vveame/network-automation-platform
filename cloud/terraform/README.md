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

The EC2-based WireGuard tunnel option has been implemented and validated.

Validated EC2 tunnel resources:

```text
public EC2 tunnel gateway
private monitoring EC2 instance
WireGuard tunnel between local DevOps VM and AWS
route table entries toward local/on-premises CIDRs
source_dest_check disabled on the tunnel gateway
user-data preparation for iptables, WireGuard tools and IP forwarding
```

The AWS managed Site-to-Site VPN module remains disabled.

No NAT Gateway is created in order to avoid unnecessary AWS cost during the student lab phase.

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
VPC CIDR:             10.50.0.0/16
Public subnet:        10.50.10.0/24
Private subnet:       10.50.20.0/24
Monitoring/AI subnet: 10.50.30.0/24
WireGuard tunnel:     10.255.0.0/30
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

`wireguard_allowed_cidr` controls UDP WireGuard access.

Because the local public IP can change frequently, WireGuard UDP can be allowed from `0.0.0.0/0` while still requiring valid peer keys. SSH must remain restrictive and should not stay open to `0.0.0.0/0`.

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

The S3 bucket is not used for Terraform remote state at this stage. Terraform state remains local during the current development phase.

### compute

Implemented as an optional module.

The compute module is disabled by default in order to avoid unnecessary AWS costs.

Legacy switch:

```hcl
enable_compute = false
```

Preferred separate switches:

```hcl
enable_tunnel_gateway      = false
enable_monitoring_instance = false
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

Target architecture:

```text
Local GNS3 / DevOps environment
        |
EdgeRouter-VPNGateway
        |
Local WireGuard endpoint
        |
WireGuard tunnel
        |
Public EC2 tunnel gateway
        |
Private monitoring EC2
```

In the first validated implementation, the local WireGuard endpoint runs on the DevOps VM. The GNS3 EdgeRouter-VPNGateway remains the logical cloud exit point and will route AWS VPC traffic toward the local tunnel endpoint.

This approach provides a practical hybrid path for the lab while keeping the monitoring EC2 private.

## EC2 Tunnel Variables

The first tunnel phase is enabled with:

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

WireGuard private keys are created manually on the local endpoint and on the AWS tunnel gateway.

Example files are stored in:

```text
cloud/tunnel/edge-router-path/examples/cloud-wg0.conf.example
cloud/tunnel/edge-router-path/examples/local-wg0.conf.example
```

The real files are created outside the repository:

```text
/etc/wireguard/wg0.conf
/etc/wireguard/cloud_private.key
/etc/wireguard/local_private.key
```

Do not commit real WireGuard configuration files.

AWS tunnel gateway:

```text
WireGuard IP: 10.255.0.1/30
Listen port: 51820/udp
```

Local tunnel endpoint:

```text
WireGuard IP: 10.255.0.2/30
Peer endpoint: <tunnel_gateway_public_ip>:51820
```

Local allowed IPs:

```text
10.255.0.1/32
10.50.0.0/16
```

AWS allowed IPs for the local peer:

```text
10.255.0.2/32
10.200.0.0/24
172.16.0.0/16
```

## Validated First Tunnel Connection

The first EC2-based hybrid tunnel has been validated.

Successful path:

```text
DevOps VM / local tunnel endpoint
    -> WireGuard tunnel
AWS EC2 tunnel gateway
    -> AWS private routing
Private monitoring EC2
```

Successful validation commands from the DevOps VM:

```bash
sudo wg show
ping -c 3 10.255.0.1

cd cloud/terraform/environments/dev
ping -c 3 "$(terraform output -raw monitoring_private_ip)"
ssh -i ~/.ssh/pfe-aws-tunnel ec2-user@"$(terraform output -raw monitoring_private_ip)"
```

Expected result:

```text
WireGuard latest handshake visible
0% packet loss to 10.255.0.1
0% packet loss to the monitoring private IP
successful SSH login to Amazon Linux 2023 on the private monitoring EC2
```

## Debugging Notes Captured in Code

During debugging, the following issues were found and fixed:

```text
The local public IP was unstable.
SSH and WireGuard needed separate CIDR controls.
AWS security group had to allow UDP/51820 for WireGuard.
EC2 source_dest_check had to be disabled on the tunnel gateway.
WireGuard packets reached the EC2 instance but were blocked by iptables.
INPUT reject rules blocked UDP/51820 until an explicit accept rule was inserted.
FORWARD reject rules blocked traffic toward the monitoring subnet.
wg0 forwarding rules had to be inserted above the default reject rule.
```

These fixes are now represented in:

```text
Terraform security group rules
compute module variables
environment variables
tunnel gateway user-data template
WireGuard example files
edge-router tunnel README
```

## Security Group Design

### Tunnel gateway / admin security group

Used by the public EC2 tunnel gateway.

Allows:

```text
SSH TCP/22 from admin_allowed_cidr
WireGuard UDP/51820 from wireguard_allowed_cidr
ICMP from tunnel/local ranges for testing
outbound traffic for routing and updates
```

### Monitoring security group

Used by the private monitoring EC2.

Allows:

```text
SSH from tunnel gateway security group
ICMP from tunnel/local ranges
Prometheus/Grafana access from tunnel/local ranges
outbound traffic
```

The monitoring EC2 does not have a public IP.

### AI security group

Reserved for future AI/anomaly-analysis service.

Allows:

```text
AI service traffic from monitoring security group
SSH from tunnel gateway security group
outbound traffic
```

### Private services security group

Reserved for future internal cloud services.

Allows internal VPC service-to-service traffic.

## Storage Design

The storage module creates a private S3 bucket for platform artifacts.

The bucket is intended for:

```text
monitoring exports
logs
AI analysis outputs
datasets
Jenkins/cloud reports
Jenkins/Ansible validation artifacts
ML outputs
remediation outputs
```

The bucket is configured with:

```text
S3 Block Public Access
BucketOwnerEnforced object ownership
versioning enabled
AES256 server-side encryption
lifecycle retention rules
```

If no custom bucket name is provided, the module generates a bucket name using the project/environment prefix and account identity.

## Validation Artifact Lifecycle

Jenkins uploads validation artifacts under:

```text
validation-artifacts/
```

Each Jenkins build receives its own prefix, for example:

```text
validation-artifacts/pfe-network-validation-43/
```

This makes validation outputs traceable per build.

Lifecycle retention variables:

```hcl
validation_artifact_retention_days = 30
noncurrent_version_retention_days  = 7
processed_summary_retention_days   = 90
anomaly_result_retention_days      = 90
```

The lifecycle policy keeps recent validation history available while automatically cleaning older artifacts.

## State Management

The first version uses local Terraform state for simplicity during development.

The S3 artifact bucket is not used for Terraform remote state at this stage.

A remote backend can be added later after the AWS baseline is stable.

Do not commit:

```text
terraform.tfstate
terraform.tfstate.backup
tfplan
*.tfplan
.terraform/
```

The provider lock file should be committed:

```text
.terraform.lock.hcl
```

This helps keep provider versions consistent across future Terraform runs.

## Credentials

AWS credentials must not be committed to GitHub.

Use one of the following methods:

```text
AWS CLI profile
environment variables
IAM role
another supported AWS provider authentication method
```

Never hard-code AWS access keys inside Terraform files.

The AWS EC2 SSH key is local only:

```text
~/.ssh/pfe-aws-tunnel
```

The public part is used in the local `terraform.tfvars` file:

```hcl
admin_public_key = "ssh-ed25519 AAAA... pfe-aws-tunnel"
```

Do not commit the private key.

Do not commit the real local `terraform.tfvars`.

## Local Variable File

The repository contains:

```text
terraform.tfvars.example
```

This file is safe to commit because it only contains example values.

The real local file:

```text
terraform.tfvars
```

must remain untracked.

Example:

```hcl
project_name = "network-automation-platform"
environment  = "dev"

aws_region        = "eu-north-1"
availability_zone = "eu-north-1a"
aws_profile       = "vviam-student"
owner             = "wiam"

vpc_cidr               = "10.50.0.0/16"
public_subnet_cidr     = "10.50.10.0/24"
private_subnet_cidr    = "10.50.20.0/24"
monitoring_subnet_cidr = "10.50.30.0/24"

admin_allowed_cidr     = "YOUR_CURRENT_PUBLIC_IP/32"
wireguard_allowed_cidr = "0.0.0.0/0"

storage_bucket_name_override = null

validation_artifact_retention_days = 30
noncurrent_version_retention_days  = 7
processed_summary_retention_days   = 90
anomaly_result_retention_days      = 90

enable_compute = false

enable_tunnel_gateway      = false
enable_monitoring_instance = false
enable_ai_instance         = false

enable_tunnel_gateway_nat_for_monitoring = true

wireguard_tunnel_cidr = "10.255.0.0/30"
wireguard_port        = 51820

compute_instance_type     = "t3.micro"
compute_ami_ssm_parameter = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"

admin_public_key = null

enable_vpn       = false
onprem_public_ip = null

onprem_cidr_blocks = [
  "10.200.0.0/24",
  "172.16.0.0/16"
]

onprem_bgp_asn = 65010
aws_bgp_asn    = 64512
```

Compute and VPN should remain disabled by default in the example file:

```hcl
enable_tunnel_gateway      = false
enable_monitoring_instance = false
enable_ai_instance         = false
enable_vpn                 = false
```

## Commands

From the dev environment:

```bash
cd cloud/terraform/environments/dev

terraform init
terraform fmt -recursive ../..
terraform validate
terraform plan
```

Apply the current baseline or enabled tunnel resources:

```bash
terraform plan -out=tfplan
terraform apply tfplan
```

Inspect deployed outputs:

```bash
terraform output
terraform output tunnel_gateway_public_ip
terraform output tunnel_gateway_private_ip
terraform output monitoring_private_ip
```

## EC2 Tunnel Validation Commands

From the local DevOps VM:

```bash
sudo wg show
ping -c 3 10.255.0.1
```

Then:

```bash
cd cloud/terraform/environments/dev

MON_IP="$(terraform output -raw monitoring_private_ip)"

ping -c 3 "$MON_IP"
ssh -i ~/.ssh/pfe-aws-tunnel ec2-user@"$MON_IP"
```

To access the public tunnel gateway by public IP during debugging:

```bash
ssh -i ~/.ssh/pfe-aws-tunnel ec2-user@"$(terraform output -raw tunnel_gateway_public_ip)"
```

To access through the private tunnel path after WireGuard is working:

```bash
ssh -i ~/.ssh/pfe-aws-tunnel ec2-user@10.255.0.1
ssh -i ~/.ssh/pfe-aws-tunnel ec2-user@"$(terraform output -raw monitoring_private_ip)"
```

## Files Not to Commit

The following files must stay local:

```text
.terraform/
terraform.tfvars
terraform.tfstate
terraform.tfstate.backup
tfplan
*.tfplan
private SSH keys
WireGuard private keys
real wg0.conf files
AWS credentials
GitHub tokens
```

The following files are safe to commit:

```text
Terraform source files
Terraform modules
user-data .tftpl templates without secrets
terraform.tfvars.example
README files
WireGuard .example files
```

## Current Status

Current AWS cloud status:

```text
Network baseline implemented.
Security baseline implemented.
S3 artifact bucket implemented.
EC2 tunnel gateway implemented.
Private monitoring EC2 implemented.
WireGuard tunnel validated.
Private monitoring EC2 reachable through the tunnel.
AWS managed Site-to-Site VPN disabled.
NAT Gateway not used.
Cloud monitoring installation pending.
Cloud AI service installation pending.
```

Next Terraform/cloud steps:

```text
1. Keep EC2 tunnel resources disabled by default in examples.
2. Keep real terraform.tfvars local.
3. Route GNS3 EdgeRouter-VPNGateway toward the local tunnel endpoint.
4. Install Prometheus and Grafana on the private monitoring EC2.
5. Configure cloud Prometheus to scrape selected local exporters through the tunnel.
6. Keep remediation execution controlled by local Jenkins/Ansible.
7. Continue using S3 as the durable artifact store.
```
