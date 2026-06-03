# Terraform Cloud Baseline

This directory contains the Terraform configuration for the cloud part of the intelligent network automation platform.

## Objective

The cloud baseline prepares the AWS environment that will later host the monitoring, analysis, storage and cloud-side services of the hybrid platform.

The local on-premises infrastructure is implemented in GNS3 and validated through Jenkins and Ansible. The cloud environment is provisioned separately using Terraform in order to keep the infrastructure reproducible, versioned and maintainable.

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

## Planned Modules

### Network

Will contain the AWS networking baseline:

- VPC
- public subnet
- private subnet
- monitoring subnet
- route tables
- internet gateway
- future VPN-related routing

### Security

Will contain cloud security controls:

- security groups
- controlled inbound access
- monitoring access rules
- future VPN-related rules

### Compute

Will contain cloud compute resources:

- monitoring instance
- AI/anomaly analysis instance
- optional bastion or management instance

### Storage

Will contain cloud storage resources:

- S3 bucket for logs
- metrics exports
- analysis outputs
- future datasets

## State Management

The first version uses local Terraform state for simplicity during development.

A remote backend can be added later after the AWS baseline is stable.

## First Commands

From the dev environment:

```bash
cd cloud/terraform/environments/dev
terraform init
terraform fmt -recursive
terraform validate
```

At this stage, no AWS resources are created because modules are still placeholders.