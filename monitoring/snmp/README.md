# SNMP Exporter Configuration

This directory documents the SNMPv3 monitoring workflow used by the local Prometheus baseline.

## Purpose

SNMP is used to collect network-device interface metrics from the FRR routers.

The project uses Prometheus SNMP Exporter to convert SNMP data into Prometheus metrics.

## Current SNMP Targets

All FRR routers are monitored over the out-of-band management network.

```text
core-frr-1    10.200.0.11:1161
core-frr-2    10.200.0.12:1161
dist-frr-1    10.200.0.21:1161
dist-frr-2    10.200.0.22:1161
edge-router   10.200.0.30:1161
```

Prometheus job:

```text
snmp-network-devices
```

SNMP Exporter module:

```text
if_mib
```

SNMP Exporter auth profile:

```text
pfe_snmpv3_authpriv
```

## Architecture

```text
FRR routers
        ↓ SNMPv3 authPriv on UDP/1161
SNMP Exporter on DevOps VM
        ↓ HTTP /snmp endpoint on localhost:9116
Prometheus
        ↓ HTTP API snapshot export
S3
        ↓ dashboard cache sync
Flask dashboard + cloud analyzer
```

## Security Model

The project uses SNMPv3 with `authPriv`.

```text
Authentication: SHA
Privacy/encryption: AES
Access type: read-only
SNMP port: UDP/1161
Allowed source: DevOps OOB IP 10.200.0.10
```

The SNMPv3 credentials are not committed to GitHub.

## Versioned Files

Safe files committed to GitHub:

```text
monitoring/snmp/snmp-auth.local.yml.example
monitoring/snmp/prometheus-snmp-exporter.default
monitoring/snmp/snmp.yml.example
monitoring/scripts/build-local-snmp-exporter-config.sh
monitoring/prometheus/targets/snmp-targets.yml
```

## Local-Only Files

Files that contain real secrets and must not be committed:

```text
monitoring/snmp/snmp-auth.local.yml
/etc/prometheus/snmp.yml
```

The local auth file contains the real SNMPv3 username/password.

The final `/etc/prometheus/snmp.yml` is generated locally and contains the official SNMP Exporter module configuration plus the local SNMPv3 auth profile.

## Build Local SNMP Exporter Config

Create the local auth file:

```bash
cp monitoring/snmp/snmp-auth.local.yml.example monitoring/snmp/snmp-auth.local.yml
nano monitoring/snmp/snmp-auth.local.yml
```

Generate and install the local SNMP Exporter config:

```bash
./monitoring/scripts/build-local-snmp-exporter-config.sh
```

The script:

```text
1. Checks for local SNMPv3 credentials.
2. Downloads or uses the official SNMP Exporter generated configuration.
3. Keeps the generated module mappings.
4. Injects the local SNMPv3 auth profile.
5. Installs the final config to /etc/prometheus/snmp.yml.
6. Restarts prometheus-snmp-exporter.
7. Tests SNMP scraping through the exporter.
```

## Prometheus Targets

The SNMP targets are versioned in:

```text
monitoring/prometheus/targets/snmp-targets.yml
```

Each target contains:

```text
target IP and port
node_name
role
source=snmp
environment=gns3-onprem-lab
```

## Validation Commands

Test direct SNMP from the DevOps VM:

```bash
for target in \
  10.200.0.11 \
  10.200.0.12 \
  10.200.0.21 \
  10.200.0.22 \
  10.200.0.30
do
  echo
  echo "=== Testing $target ==="
  snmpwalk -v3 \
    -l authPriv \
    -u pfe_snmp_ro \
    -a SHA \
    -A 'REAL_LONG_AUTH_PASSWORD' \
    -x AES \
    -X 'REAL_LONG_PRIV_PASSWORD' \
    "$target:1161" \
    1.3.6.1.2.1.1.5.0
done
```

Expected result: each router returns its hostname.

Test SNMP Exporter:

```bash
curl -fsS "http://localhost:9116/snmp?target=10.200.0.30:1161&module=if_mib&auth=pfe_snmpv3_authpriv" \
  | grep -Ei "ifOperStatus|ifAdminStatus|ifHCInOctets|ifHCOutOctets|sysUpTime"
```

Test Prometheus:

```bash
curl -fsS --get "http://localhost:9090/api/v1/query" \
  --data-urlencode 'query=up{job="snmp-network-devices"}' | python3 -m json.tool

curl -fsS --get "http://localhost:9090/api/v1/query" \
  --data-urlencode 'query=ifOperStatus{job="snmp-network-devices"}' | python3 -m json.tool
```

Expected result:

```text
5 SNMP targets up
interface metrics returned for all FRR routers
```

## Metrics Used

The current monitoring/analyzer baseline uses:

```text
up{job="snmp-network-devices"}
sysUpTime
ifAdminStatus
ifOperStatus
ifHCInOctets
ifHCOutOctets
ifInErrors
ifOutErrors
```

These metrics support the first anomaly-detection baseline:

```text
SNMP target down
router interface unexpectedly down
interface errors detected
traffic counters available for future trend analysis
```

## Interface Health Notes

The dashboard can display loopback and VRRP interfaces for visibility.

For anomaly scoring:

```text
lo interfaces are ignored
vrrp* interfaces are ignored
physical and routed interfaces are health-relevant
```

This avoids false alerts for VRRP backup virtual interfaces.

## Do Not Commit

Never commit:

```text
monitoring/snmp/snmp-auth.local.yml
/etc/prometheus/snmp.yml
```
