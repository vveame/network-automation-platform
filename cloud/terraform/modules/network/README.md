# Network Module

This module creates the first AWS networking baseline for the hybrid network automation platform.

## Resources

The module creates:

- one VPC
- one public subnet
- one private subnet
- one monitoring / AI subnet
- one Internet Gateway
- one public route table
- one private route table
- one monitoring route table
- route table associations

## Design Notes

Only the public subnet is connected to the Internet Gateway.

The private and monitoring subnets are intentionally kept isolated at this stage. They will later be connected through controlled routing, VPN, or dedicated endpoints depending on the next cloud implementation steps.

No NAT Gateway is created in this module in order to avoid unnecessary AWS costs during the student lab phase.
