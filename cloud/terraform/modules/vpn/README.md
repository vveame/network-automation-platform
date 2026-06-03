# VPN Module

This module prepares the future AWS Site-to-Site VPN layer for the hybrid network automation platform.

## Purpose

The VPN module is designed to connect the local GNS3/on-premises network to the AWS VPC.

Target design:

```text
GNS3 EdgeRouter / VPN Gateway
        ↕
AWS Site-to-Site VPN
        ↕
AWS VPC
```

## Cost Safety

VPN is disabled by default.

```hcl
enable_vpn = false
```

No AWS VPN resources are created unless this value is explicitly changed to `true`.

## Planned Resources

When enabled, this module creates:

* AWS Customer Gateway
* AWS Virtual Private Gateway
* AWS Site-to-Site VPN connection
* static VPN routes
* VPC route table routes toward on-premises CIDRs

## Routing Model

The first version uses static routing.

Default on-premises CIDR blocks:

```text
10.200.0.0/24
172.16.0.0/16
```

These CIDRs can be changed later depending on the final local topology routing plan.

## Variables

| Variable             | Purpose                                               |
| -------------------- | ----------------------------------------------------- |
| `enable_vpn`         | Enables or disables VPN resource creation             |
| `onprem_public_ip`   | Public IP address of the on-premises customer gateway |
| `onprem_cidr_blocks` | Local/on-premises networks routed through the VPN     |
| `onprem_bgp_asn`     | ASN for the customer gateway side                     |
| `aws_bgp_asn`        | ASN for the AWS virtual private gateway               |

## Important Notes

A real AWS Site-to-Site VPN requires a reachable public IP address for the on-premises customer gateway.

If the GNS3 EdgeRouter is behind VMware NAT or a home router without a stable public endpoint, a real AWS VPN cannot be completed directly without an additional public endpoint or tunneling design.

VPN tunnel pre-shared keys and generated VPN configuration details can appear in Terraform state. The state file must therefore be protected before enabling VPN resources.

## Current Status

This module is implemented but disabled.

With the default value:

```hcl
enable_vpn = false
```

Terraform creates no VPN resources and only exposes the disabled VPN state through outputs.
