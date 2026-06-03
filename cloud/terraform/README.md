# Terraform Cloud Baseline

This directory contains the Terraform configuration for the AWS cloud part of the intelligent network automation platform.

## Objective

The cloud baseline prepares the AWS environment that will later host the monitoring, analysis, storage and cloud-side services of the hybrid platform.

The local on-premises infrastructure is implemented in GNS3 and validated through Jenkins and Ansible. The cloud environment is provisioned separately using Terraform in order to keep the infrastructure reproducible, versioned and maintainable.

## Current Implementation Status

The current Terraform baseline implements the first AWS network, security and storage foundation.

It creates:

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

No EC2 instances, NAT Gateway, VPN connection, monitoring services or AI services are created yet.

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
│   └── storage/
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

The security module prepares controlled access rules for future cloud services without deploying compute instances yet.

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

Planned.

Will contain cloud compute resources:

* monitoring instance
* AI/anomaly analysis instance
* optional bastion or management instance

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

### AI security group

Reserved for the future anomaly detection / AI analysis service.

Allows AI service traffic on TCP/8000 from the monitoring security group.

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

The bucket is configured with:

* S3 Block Public Access
* `BucketOwnerEnforced` object ownership
* versioning enabled
* AES256 server-side encryption

If no custom bucket name is provided, the module generates a deterministic bucket name using:

```text
<project-name>-<environment>-artifacts-<aws-account-id>
```

## Design Notes

The cloud baseline is intentionally simple and low-cost.

A NAT Gateway is not created at this stage in order to avoid unnecessary AWS costs during the student lab phase.

The private and monitoring subnets will later be connected through controlled routing, VPN, or dedicated access mechanisms depending on the next implementation steps.

Security group rules are managed as standalone Terraform resources instead of inline security group rules. This keeps rule management clearer and avoids conflicts between inline and standalone rule definitions.

The S3 bucket is not used for Terraform remote state at this stage. It is reserved for platform artifacts, logs, metrics exports and future AI analysis outputs.

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
```

In `terraform.tfvars.example`, the admin CIDR should remain restrictive:

```hcl
admin_allowed_cidr = "0.0.0.0/32"
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
