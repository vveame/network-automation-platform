# Terraform Cloud Baseline

This directory contains the Terraform configuration for the AWS cloud part of the intelligent network automation platform.

## Objective

The cloud baseline prepares the AWS environment that will later host the monitoring, analysis, storage and cloud-side services of the hybrid platform.

The local on-premises infrastructure is implemented in GNS3 and validated through Jenkins and Ansible. The cloud environment is provisioned separately using Terraform in order to keep the infrastructure reproducible, versioned and maintainable.

## Current Implementation Status

The first cloud implementation step is complete.

The implemented Terraform baseline creates:

* one AWS VPC
* one public subnet
* one private subnet
* one monitoring / AI subnet
* one Internet Gateway
* one public route table
* one private route table
* one monitoring route table
* route table associations for the three subnets

No EC2 instances, NAT Gateway, VPN connection, monitoring services, AI services or S3 buckets are created yet.

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

Planned.

Will contain cloud security controls:

* security groups
* controlled SSH/admin access
* monitoring access rules
* future VPN-related rules

### compute

Planned.

Will contain cloud compute resources:

* monitoring instance
* AI/anomaly analysis instance
* optional bastion or management instance

### storage

Planned.

Will contain cloud storage resources:

* S3 bucket for logs
* metrics exports
* analysis outputs
* future datasets

## Design Notes

The cloud baseline is intentionally simple and low-cost.

A NAT Gateway is not created at this stage in order to avoid unnecessary AWS costs during the student lab phase.

The private and monitoring subnets will later be connected through controlled routing, VPN, or dedicated access mechanisms depending on the next implementation steps.

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

Apply the current network baseline:

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
