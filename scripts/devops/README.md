# DevOps Runtime Scripts

This folder contains scripts executed from the DevOps VM.

The DevOps VM is the automation/control node. It does not terminate the final WireGuard tunnel and does not provide the final tunnel underlay NAT.

## Final Runtime Model

```text
DevOps VM:
  Jenkins
  Ansible
  Terraform
  AWS CLI
  GitHub runner trigger bridge
  Local route to AWS private VPC through EdgeRouter
  Local SSH tunnels to cloud Prometheus/Grafana

EdgeRouter-VPNGateway:
  Direct internet underlay through eth3
  WireGuard tunnel endpoint through wg0
  OOB management through eth4 / 10.200.0.30

AWS:
  Public EC2 tunnel gateway
  Private monitoring EC2
  Private S3 artifact bucket
```

## Active Scripts

### `refresh-gns3-known-hosts.sh`

Refreshes SSH host keys for GNS3 containers after container recreation.

Run from DevOps:

```bash
./scripts/devops/refresh-gns3-known-hosts.sh
```

### `route-cloud-via-edge-router.sh`

Installs the DevOps route to reach the AWS private VPC through the EdgeRouter tunnel.

Runtime route:

```text
10.50.0.0/16 via 10.200.0.30 dev ens34
```

Run from DevOps:

```bash
sudo ./scripts/devops/route-cloud-via-edge-router.sh
```

### `apply-cloud-monitoring-access-to-oob-nodes.sh`

Applies live cloud monitoring access rules to all OOB-managed FRR and OVS nodes.

It allows the private AWS monitoring EC2 and WireGuard gateway-side source to scrape local SNMPv3 endpoints.

Run from DevOps:

```bash
./scripts/devops/apply-cloud-monitoring-access-to-oob-nodes.sh
```

### `enable-monitoring-egress-nat-on-tunnel-gateway.sh`

Repairs or enables AWS-side egress NAT for the private monitoring EC2 subnet.

This is not local DevOps NAT.

Expected AWS egress path:

```text
Private monitoring EC2
    -> monitoring route table 0.0.0.0/0
    -> AWS EC2 tunnel gateway ENI
    -> iptables MASQUERADE
    -> Internet Gateway
    -> Internet
```

Run from DevOps:

```bash
./scripts/devops/enable-monitoring-egress-nat-on-tunnel-gateway.sh
```

### `cloud-monitoring-ui-tunnel.sh`

Opens local DevOps background tunnels to cloud Prometheus and Grafana.

Default local URLs on DevOps:

```text
Prometheus: http://127.0.0.1:19090
Grafana:    http://127.0.0.1:13000
```

Run from DevOps:

```bash
./scripts/devops/cloud-monitoring-ui-tunnel.sh restart
./scripts/devops/cloud-monitoring-ui-tunnel.sh status
./scripts/devops/cloud-monitoring-ui-tunnel.sh stop
```

### `restore-full-hybrid-tunnel.sh`

Main post-restart repair script.

Run from DevOps:

```bash
./scripts/devops/restore-full-hybrid-tunnel.sh
```

It performs:

```text
Refresh GNS3 SSH known_hosts
Confirm EdgeRouter eth3 direct internet underlay
Install DevOps AWS VPC route through EdgeRouter
Ensure EdgeRouter WireGuard is running
Apply cloud monitoring access rules to OOB nodes
Repair AWS monitoring EC2 egress NAT
Validate tunnel reachability
Open cloud Prometheus/Grafana UI tunnel
```


## Local Jenkins Trigger Configuration

The GitHub Actions self-hosted runner should only call the protected local trigger script:

```text
/usr/local/sbin/trigger-jenkins-pfe
```

The trigger script reads local-only runtime values from:

```text
/etc/pfe/jenkins-hybrid.env
```

This file must be root-owned and must not be committed.

Example values:

```bash
JENKINS_URL="http://127.0.0.1:8080"
JENKINS_JOB_PATH="job/pfe-network-validation"

PIPELINE_MODE="AUTO"
CONFIRM_APPLY="false"

AUTO_PUSH_IMAGES="true"
DOCKERHUB_NAMESPACE="vviam"
IMAGE_TAG="latest"
GNS3_HOST="YOUR_GNS3_VM_IP"

EXPORT_ARTIFACTS_TO_S3="true"
S3_ARTIFACTS_BUCKET="YOUR_BUCKET_NAME"
CLOUD_AWS_REGION="eu-north-1"

AWS_MONITORING_HOST="10.50.30.154"
AWS_MONITORING_USER="ec2-user"
CLOUD_PROMETHEUS_URL="http://localhost:9090"

ENABLE_ML_ANALYZER="true"
TRAIN_ML_MODEL="false"
ML_FEATURES_FILE="cloud/analyzer/ml/features.cloud.json"

ENABLE_SAFE_REMEDIATION="true"
REMEDIATION_MODE="plan"
EDGE_UNDERLAY_MODE="direct"
```

Secure the file:

```bash
sudo chown root:root /etc/pfe/jenkins-hybrid.env
sudo chmod 600 /etc/pfe/jenkins-hybrid.env
```

## Windows Access to Cloud Grafana and Prometheus

After `cloud-monitoring-ui-tunnel.sh` is running on DevOps, open a second tunnel from Windows:

```powershell
ssh -N `
  -L 19090:127.0.0.1:19090 `
  -L 13000:127.0.0.1:13000 `
  wiam@DEVOPS_VM_IP
```

Then open on Windows:

```text
http://127.0.0.1:19090
http://127.0.0.1:13000
```

## Run Order After GNS3 Restart

On GNS3 VM:

```bash
cd /home/gns3/pfe-repo
git pull origin main
./gns3/scripts/bootstrap-persistent-gns3.sh
```

Start or restart the topology.

On DevOps VM:

```bash
cd ~/pfe-repo
git pull origin main
./scripts/devops/restore-full-hybrid-tunnel.sh
```

## Validation Commands

Check EdgeRouter direct underlay:

```bash
TGW_PUBLIC_IP="$(cd cloud/terraform/environments/dev && terraform output -raw tunnel_gateway_public_ip)"

ssh root@10.200.0.30 "ip route get $TGW_PUBLIC_IP"
ssh root@10.200.0.30 "ip route get 8.8.8.8"
```

Expected:

```text
dev eth3
```

Check WireGuard:

```bash
ssh root@10.200.0.30 "wg show wg0"
ssh root@10.200.0.30 "ping -c 3 10.255.0.1"
ssh root@10.200.0.30 "ping -c 3 10.50.30.154"
```

Check DevOps route to AWS:

```bash
ip route get 10.50.30.154
```

Expected:

```text
via 10.200.0.30 dev ens34
```
