# Security Module

This module creates the first AWS security group baseline for the hybrid network automation platform.

## Resources

The module creates:

- admin security group
- monitoring security group
- AI analysis security group
- private services security group
- standalone ingress and egress security group rules

## Security Groups

### admin

Reserved for a future bastion or management instance.

Allows SSH only from the configured admin public CIDR.

### monitoring

Reserved for future Prometheus and Grafana services.

Allows:

- Grafana access on TCP/3000 from the configured admin public CIDR
- Prometheus access on TCP/9090 from the configured admin public CIDR
- internal metrics traffic on TCP/9100 from the VPC CIDR

### ai

Reserved for the future anomaly detection / AI analysis service.

Allows AI service traffic on TCP/8000 from the monitoring security group.

### private

Reserved for future private cloud services.

Allows internal VPC service-to-service traffic.

## Notes

Security group rules are managed as standalone Terraform resources.

This avoids mixing inline rules and standalone rules, which can cause rule management conflicts.
