# Terraform Cloud Baseline

This directory contains the Terraform configuration for the AWS cloud part of the intelligent network automation platform.

## Objective

The cloud baseline prepares the AWS environment that will later host the monitoring, analysis, storage and cloud-side services of the hybrid platform.

The local on-premises infrastructure is implemented in GNS3 and validated through Jenkins and Ansible. The cloud environment is provisioned separately using Terraform in order to keep the infrastructure reproducible, versioned and maintainable.

## Current Implementation Status

The current Terraform baseline implements the first AWS network, security, storage, optional compute and disabled VPN foundation.

It creates or prepares:

* one AWS VPC
* one public subnet
* one private subnet
* one monitoring / AI subnet
* one Internet Gateway
* one public route table
* one private route table
* one monitoring route table
* route table associations for the three subnets
* one admin security group
* one monitoring security group
* one AI analysis security group
* one private services security group
* standalone security group ingress and egress rules
* one private S3 artifacts bucket
* S3 public access blocking
* S3 ownership controls
* S3 versioning
* S3 server-side encryption
* optional EC2 compute placeholders, disabled by default
* AWS Site-to-Site VPN module, disabled by default

No EC2 instances, NAT Gateway, active VPN connection, monitoring services or AI services are created yet unless explicitly enabled.

## Structure

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
│   ├── storage/
│   └── vpn/
└── README.md
```

## Environment

The current environment is:

```text
environments/dev
```

It represents the first development cloud environment for the PFE lab.

The default cloud CIDR plan is:

```text
VPC CIDR:              10.50.0.0/16
Public subnet:         10.50.10.0/24
Private subnet:        10.50.20.0/24
Monitoring/AI subnet:  10.50.30.0/24
```

## Modules

### network

Implemented.

Creates the AWS networking baseline:

* VPC
* public subnet
* private subnet
* monitoring / AI subnet
* Internet Gateway
* route tables
* route table associations

Only the public subnet has a default route to the Internet Gateway.

The private and monitoring subnets remain isolated for now.

### security

Implemented.

Creates the AWS security group baseline:

* admin security group
* monitoring security group
* AI analysis security group
* private services security group
* standalone ingress and egress rules

The security module prepares controlled access rules for future cloud services.

It also prepares SSH access from the future admin/bastion security group toward the future monitoring and AI instances.

### storage

Implemented.

Creates the AWS storage baseline:

* private S3 artifacts bucket
* public access block
* bucket owner enforced ownership controls
* versioning
* server-side encryption

The storage bucket is reserved for future logs, metrics exports, AI outputs, datasets and Jenkins/cloud reports.

### compute

Implemented as an optional module.

The compute module is disabled by default in order to avoid unnecessary AWS costs.

It is controlled by:

```hcl
enable_compute = false
```

When enabled, it can create:

* one bastion/admin EC2 instance in the public subnet
* one monitoring placeholder EC2 instance in the monitoring subnet
* one AI analysis placeholder EC2 instance in the monitoring subnet
* one EC2 key pair if a public SSH key is provided

At the current stage, compute remains disabled and no EC2 instances are created.

### vpn

Implemented as a disabled hybrid connectivity module.

The VPN module is disabled by default in order to avoid unnecessary AWS VPN costs and to prevent premature exposure.

It is controlled by:

```hcl
enable_vpn = false
```

When enabled, it can create:

* AWS Customer Gateway
* AWS Virtual Private Gateway
* AWS Site-to-Site VPN connection
* static VPN routes
* VPC route table routes toward on-premises CIDRs

At the current stage, VPN remains disabled and no AWS VPN resources are created.

## Security Group Design

### Admin security group

Reserved for a future bastion or management instance.

Allows SSH only from the configured administrator public CIDR.

### Monitoring security group

Reserved for future Prometheus and Grafana services.

Allows:

* Grafana access on TCP/3000 from the configured admin public CIDR
* Prometheus access on TCP/9090 from the configured admin public CIDR
* internal metrics traffic on TCP/9100 from the VPC CIDR
* SSH from the future admin/bastion security group

### AI security group

Reserved for the future anomaly detection / AI analysis service.

Allows:

* AI service traffic on TCP/8000 from the monitoring security group
* SSH from the future admin/bastion security group

### Private services security group

Reserved for future private cloud services.

Allows internal VPC service-to-service traffic.

## Storage Design

The storage module creates a private S3 bucket for future cloud-side artifacts.

The bucket is intended for:

* monitoring exports
* logs
* AI analysis outputs
* datasets
* Jenkins/cloud reports
* Jenkins/Ansible validation artifacts

The bucket is configured with:

* S3 Block Public Access
* `BucketOwnerEnforced` object ownership
* versioning enabled
* AES256 server-side encryption
* lifecycle retention rules for validation artifacts

If no custom bucket name is provided, the module generates a deterministic bucket name using:

```text
<project-name>-<environment>-artifacts-<aws-account-id>
```

### Validation Artifact Lifecycle

Jenkins uploads validation artifacts under:

```text
validation-artifacts/
```

Each Jenkins build receives its own prefix, for example:

```text
validation-artifacts/pfe-network-validation-43/
```

This makes validation outputs traceable per build.

To prevent unnecessary storage growth, the storage module defines lifecycle retention variables:

```hcl
validation_artifact_retention_days = 30
noncurrent_version_retention_days  = 7
```

The lifecycle policy applies to:

```text
validation-artifacts/
```

The default behavior is:

* delete validation artifact objects after 30 days
* delete noncurrent object versions after 7 days
* abort incomplete multipart uploads after 1 day

This keeps recent validation history available while automatically cleaning older artifacts.

### Important Note

The S3 bucket is not used for Terraform remote state at this stage.

Terraform state remains local during the current development phase. The S3 bucket is reserved for platform artifacts, logs, metrics exports, reports and future AI analysis outputs.

## Compute Design

The compute module prepares the future cloud execution layer.

When enabled, the planned EC2 layout is:

| Instance      | Subnet                 | Public IP | Purpose                                               |
| ------------- | ---------------------- | --------- | ----------------------------------------------------- |
| Bastion/admin | Public subnet          | Yes       | Controlled administrative entry point                 |
| Monitoring    | Monitoring / AI subnet | No        | Future Prometheus, Grafana and telemetry ingestion    |
| AI analysis   | Monitoring / AI subnet | No        | Future anomaly detection and decision-support service |

The monitoring and AI instances are private and are intended to be accessed through the bastion/admin instance or future hybrid/VPN routing.

## Hybrid / VPN Design

The VPN module prepares the future hybrid connectivity layer.

The intended design is:

```text
Local GNS3 on-premises network
        ↕
GNS3 EdgeRouter / VPN Gateway
        ↕
AWS Site-to-Site VPN
        ↕
AWS VPC
```

The first VPN model uses static routing.

Default on-premises CIDRs prepared for future VPN routing:

```text
10.200.0.0/24
172.16.0.0/16
```

A real AWS Site-to-Site VPN requires a reachable public IP address for the on-premises customer gateway.

If the GNS3 EdgeRouter is behind VMware NAT or a home router without a stable public endpoint, another hybrid connectivity strategy may be required before enabling real VPN resources.

VPN tunnel configuration details and pre-shared keys can appear in Terraform state. For that reason, VPN remains disabled until the state storage and connectivity strategy are reviewed.

## Design Notes

The cloud baseline is intentionally simple and low-cost.

A NAT Gateway is not created at this stage in order to avoid unnecessary AWS costs during the student lab phase.

The private and monitoring subnets will later be connected through controlled routing, VPN, or dedicated access mechanisms depending on the next implementation steps.

Security group rules are managed as standalone Terraform resources instead of inline security group rules. This keeps rule management clearer and avoids conflicts between inline and standalone rule definitions.

The S3 bucket is not used for Terraform remote state at this stage. It is reserved for platform artifacts, logs, metrics exports and future AI analysis outputs.

The compute module is prepared but disabled by default. This allows the architecture to be documented and versioned without creating running EC2 resources until they are needed.

The VPN module is prepared but disabled by default. This allows the hybrid architecture to be represented in Terraform without creating billable VPN resources until the real connectivity strategy is selected.

## State Management

The first version uses local Terraform state for simplicity during development.

A remote backend can be added later after the AWS baseline is stable.

## Credentials

AWS credentials must not be committed to GitHub.

Use one of the following methods:

* AWS CLI profile
* environment variables
* IAM role
* another supported AWS provider authentication method

Never hard-code access keys inside Terraform files.

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

aws_profile = "vviam-student"
owner       = "wiam"

vpc_cidr               = "10.50.0.0/16"
public_subnet_cidr     = "10.50.10.0/24"
private_subnet_cidr    = "10.50.20.0/24"
monitoring_subnet_cidr = "10.50.30.0/24"

admin_allowed_cidr = "YOUR_PUBLIC_IP/32"

storage_bucket_name_override = null

validation_artifact_retention_days = 30
noncurrent_version_retention_days  = 7

enable_compute        = false
compute_instance_type = "t3.micro"
compute_ami_ssm_parameter = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
admin_public_key = null

enable_vpn = false
onprem_public_ip = null
onprem_cidr_blocks = [
  "10.200.0.0/24",
  "172.16.0.0/16"
]
onprem_bgp_asn = 65010
aws_bgp_asn    = 64512
```

In `terraform.tfvars.example`, the admin CIDR should remain restrictive:

```hcl
admin_allowed_cidr = "0.0.0.0/32"
```

Compute and VPN should remain disabled by default:

```hcl
enable_compute = false
enable_vpn     = false
```

## Commands

From the dev environment:

```bash
cd cloud/terraform/environments/dev

terraform init
terraform fmt -recursive
terraform validate
terraform plan
```

Apply the current baseline:

```bash
terraform plan -out=tfplan
terraform apply tfplan
```

Inspect deployed outputs:

```bash
terraform output
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
```

The provider lock file should be committed:

```text
.terraform.lock.hcl
```

This helps keep provider versions consistent across future Terraform runs.
