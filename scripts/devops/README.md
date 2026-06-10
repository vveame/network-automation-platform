## Monitoring EC2 Egress Through Tunnel Gateway NAT Instance

The private monitoring EC2 instance does not have a public IP address. To avoid the cost of an AWS NAT Gateway, the public EC2 tunnel gateway is also used as a small NAT/routing instance for the monitoring subnet.

Expected egress path:

```text
Private monitoring EC2
    -> monitoring route table 0.0.0.0/0
    -> AWS EC2 tunnel gateway ENI
    -> iptables MASQUERADE
    -> Internet Gateway
    -> internet
```

The helper script below enables or repairs the NAT rules on an existing tunnel gateway instance:

```bash
./cloud/scripts/enable-monitoring-egress-nat-on-tunnel-gateway.sh
```

Run order from the DevOps VM:

```bash
sudo ./scripts/devops/route-cloud-via-edge-router.sh
./cloud/scripts/enable-monitoring-egress-nat-on-tunnel-gateway.sh
```

This keeps the monitoring EC2 private while still allowing it to install Prometheus, Grafana and other monitoring packages.
