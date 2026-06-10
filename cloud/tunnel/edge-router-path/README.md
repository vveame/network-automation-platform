# EC2 Tunnel Through the Edge Router Path

This directory documents the first validated hybrid connectivity implementation between the local GNS3/DevOps environment and the AWS VPC.

The objective is to connect the local network automation platform to AWS without using the managed AWS Site-to-Site VPN service. This choice was made because the lab environment does not have a stable public IP address on the local side, and because the managed VPN service introduces additional cost and complexity for a student project.

Instead, the platform uses a public EC2 instance as a WireGuard tunnel gateway.

## Target Architecture

```text
Local GNS3 / DevOps environment
        |
        | local routing
        v
EdgeRouter-VPNGateway
        |
        | route toward local tunnel endpoint
        v
Local WireGuard endpoint
        |
        | encrypted WireGuard tunnel
        v
AWS EC2 Tunnel Gateway
        |
        | AWS private routing
        v
Private Monitoring EC2
```

In the first validated implementation, the local WireGuard endpoint runs on the DevOps VM. The EdgeRouter-VPNGateway remains the logical cloud exit point of the local architecture and must route AWS VPC traffic toward the local tunnel endpoint.

This approach allows the project to validate a real hybrid communication path while keeping the AWS monitoring instance private.

## Validated Connection

The following path was successfully validated:

```text
DevOps VM / local tunnel endpoint
    -> WireGuard tunnel
AWS tunnel gateway: 10.255.0.1
    -> AWS private routing
Private monitoring EC2: 10.50.30.x
```

Successful tests:

```bash
ping -c 3 10.255.0.1
ping -c 3 <monitoring_private_ip>
ssh -i ~/.ssh/pfe-aws-tunnel ec2-user@<monitoring_private_ip>
```

The successful SSH login to the private monitoring EC2 confirms that the private AWS instance is reachable only through the hybrid tunnel path.

## CIDR Plan

```text
AWS VPC:              10.50.0.0/16
Public subnet:        10.50.10.0/24
Private subnet:       10.50.20.0/24
Monitoring subnet:    10.50.30.0/24
WireGuard tunnel:     10.255.0.0/30
AWS tunnel IP:        10.255.0.1
Local tunnel IP:      10.255.0.2
Local OOB/lab CIDR:   10.200.0.0/24
GNS3 internal CIDR:   172.16.0.0/16
```

## Terraform Resources

The tunnel is prepared using Terraform.

The implementation adds:

```text
1 public EC2 tunnel gateway
1 private EC2 monitoring instance
security groups for SSH, WireGuard, monitoring and private services
routes from AWS private/monitoring route tables toward local CIDRs
source_dest_check = false on the tunnel gateway
SSM IAM instance profile for future administrative access
user-data scripts for tunnel preparation
```

The tunnel gateway is created in the public subnet and has a public IP.

The monitoring instance is created in the monitoring subnet and does not have a public IP.

## Important Terraform Variables

The EC2 tunnel is disabled by default to avoid unnecessary cost.

To enable the first tunnel phase:

```hcl
enable_tunnel_gateway      = true
enable_monitoring_instance = true
enable_ai_instance         = false
enable_vpn                 = false
```

WireGuard variables:

```hcl
wireguard_tunnel_cidr = "10.255.0.0/30"
wireguard_port        = 51820
```

The local/on-premises routes are defined with:

```hcl
onprem_cidr_blocks = [
  "10.200.0.0/24",
  "172.16.0.0/16"
]
```

## SSH and WireGuard CIDR Separation

During implementation, the local public IP was found to be unstable. Because of that, SSH and WireGuard access are separated.

```hcl
admin_allowed_cidr     = "YOUR_CURRENT_PUBLIC_IP/32"
wireguard_allowed_cidr = "0.0.0.0/0"
```

`admin_allowed_cidr` controls SSH access only.

`wireguard_allowed_cidr` controls UDP access to the WireGuard port.

WireGuard can safely listen on UDP/51820 from a wider CIDR because it still requires valid cryptographic peer keys. SSH must not remain open to the whole internet.

Temporary debugging only:

```hcl
admin_allowed_cidr = "0.0.0.0/0"
```

This must be closed again after the tunnel is validated.

## WireGuard Configuration

WireGuard private keys are not stored in Terraform and must never be committed to Git.

Example templates are provided:

```text
cloud/tunnel/edge-router-path/examples/cloud-wg0.conf.example
cloud/tunnel/edge-router-path/examples/local-wg0.conf.example
```

The AWS side uses:

```text
10.255.0.1/30
```

The local side uses:

```text
10.255.0.2/30
```

The local endpoint points to the public EC2 tunnel gateway:

```ini
Endpoint = <tunnel_gateway_public_ip>:51820
```

## AWS Tunnel Gateway Firewall Fixes

During debugging, WireGuard packets reached the EC2 instance but were blocked by the local instance firewall.

The default iptables rules contained a reject rule before the WireGuard forwarding rules:

```text
-A INPUT -j REJECT --reject-with icmp-host-prohibited
-A FORWARD -j REJECT --reject-with icmp-host-prohibited
```

The fix was to insert WireGuard and forwarding rules above the reject rules.

The tunnel gateway user-data now prepares:

```text
IP forwarding
UDP/51820 INPUT allow rule
FORWARD rules for wg0 traffic
FORWARD rules for AWS VPC traffic
optional NAT for the monitoring subnet
```

The working rule logic is:

```text
Allow WireGuard UDP before INPUT reject
Allow wg0 forwarding before FORWARD reject
Allow established/related forwarded traffic
Allow AWS VPC traffic back toward wg0
```

## First Connection Validation Commands

From the local DevOps VM:

```bash
sudo systemctl restart wg-quick@wg0
sudo wg show

ping -c 3 10.255.0.1
```

Expected result:

```text
latest handshake: a few seconds ago
transfer: ... received, ... sent
0% packet loss to 10.255.0.1
```

Then test the private monitoring EC2:

```bash
cd ~/pfe-repo/cloud/terraform/environments/dev

MON_IP="$(terraform output -raw monitoring_private_ip)"

ping -c 3 "$MON_IP"
ssh -i ~/.ssh/pfe-aws-tunnel ec2-user@"$MON_IP"
```

Expected result:

```text
0% packet loss to the monitoring private IP
successful SSH login to Amazon Linux 2023
```

## Access Model

After the tunnel is working, the preferred access model is:

```text
Public SSH: temporary administration only
WireGuard: permanent hybrid access path
Private monitoring SSH: through the WireGuard tunnel
```

Access to the private monitoring EC2 should be performed through:

```bash
ssh -i ~/.ssh/pfe-aws-tunnel ec2-user@<monitoring_private_ip>
```

The public tunnel gateway can also be reached privately through:

```bash
ssh -i ~/.ssh/pfe-aws-tunnel ec2-user@10.255.0.1
```

## Security Notes

Do not commit:

```text
terraform.tfvars
terraform.tfstate
tfplan
private SSH keys
WireGuard private keys
real wg0.conf files
GitHub tokens
AWS credentials
```

The AWS EC2 SSH key is local only:

```text
~/.ssh/pfe-aws-tunnel
```

The WireGuard keys are also local/instance-specific and must not be pushed to GitHub.

If a private WireGuard key is accidentally exposed, regenerate both WireGuard key pairs and update the peer public keys.

## Current Status

The first EC2-based hybrid tunnel has been validated.

Confirmed:

```text
DevOps VM can reach AWS tunnel gateway over WireGuard.
DevOps VM can ping the private monitoring EC2.
DevOps VM can SSH into the private monitoring EC2 through the tunnel.
The monitoring EC2 remains private and has no public IP.
```

Next steps:

```text
1. Route the GNS3 EdgeRouter-VPNGateway toward the local WireGuard endpoint.
2. Move Prometheus/Grafana deployment to the private monitoring EC2.
3. Configure cloud Prometheus to scrape selected local exporters through the tunnel.
4. Keep remediation execution controlled from the local Jenkins/Ansible side.
5. Use S3 for durable artifact storage and dashboard synchronization.
```
