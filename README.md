# Intelligent Network Automation Platform

This repository contains the versioned configuration files for the local network infrastructure used in the intelligent network automation platform.

## Objective

The goal is to transform the validated manual GNS3 configuration into reusable, traceable and automatable files.

## Main Components

- Open vSwitch for Layer 2 switching, VLANs and trunks.
- FRRouting for Layer 3 routing and OSPF.
- Linux scripts for interface configuration.
- Security scripts for firewall rules.
- Ansible and Jenkins placeholders for future automation.
- Terraform placeholders for future cloud provisioning.
- Monitoring and AI folders for future observability and anomaly detection.

## Deployment Order

1. Apply OVS configurations.
2. Apply FRR Linux interface configurations.
3. Apply FRR routing configurations.
4. Configure host IP addresses.
5. Validate connectivity.
6. Apply security rules.
7. Integrate with Ansible and Jenkins.
8. Add monitoring and anomaly detection.

## Current Status

Initial connectivity has been validated manually in GNS3.
The working configuration is now being converted into versioned files.