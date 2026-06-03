# Compute Module

This module prepares optional EC2 placeholder instances for the cloud side of the hybrid network automation platform.

## Purpose

The compute layer is reserved for future cloud services:

* bastion/admin access node
* monitoring node
* AI/anomaly analysis node

## Cost Safety

Compute is disabled by default.

The module creates EC2 instances only when:

```hcl
enable_compute = true
```

This avoids unnecessary AWS costs during the student lab phase.

## Resources

When enabled, the module creates:

* one EC2 key pair, if an SSH public key is provided
* one bastion/admin instance in the public subnet
* one monitoring placeholder instance in the monitoring subnet
* one AI analysis placeholder instance in the monitoring subnet

## Design

### Bastion / admin instance

Placed in the public subnet.

It receives a public IP address and uses the admin security group.

This instance is designed to become the controlled administrative entry point into the cloud environment.

### Monitoring instance

Placed in the monitoring / AI subnet.

It does not receive a public IP address.

It is reserved for future Prometheus, Grafana and telemetry ingestion services.

### AI analysis instance

Placed in the monitoring / AI subnet.

It does not receive a public IP address.

It is reserved for future anomaly detection and decision-support services.

## Access Model

The bastion/admin instance is the only planned public EC2 entry point.

The monitoring and AI instances are private and will be accessed through:

* the bastion/admin instance
* or a future hybrid VPN path
* or controlled automation workflows

Security group rules allow SSH from the admin security group to the monitoring and AI security groups.

## AMI Selection

The module retrieves the Amazon Linux 2023 AMI using a public SSM parameter:

```hcl
/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64
```

This avoids hardcoding region-specific AMI IDs.

## Notes

This module does not install Prometheus, Grafana or AI software yet.

It only prepares the EC2 infrastructure placeholders.

The module is safe to keep in the repository because EC2 creation is controlled through `enable_compute`.
