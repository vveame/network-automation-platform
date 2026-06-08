# SNMP Exporter Configuration

This directory documents the SNMPv3 monitoring workflow used by the local Prometheus baseline.

## Purpose

SNMP is used to collect network-device interface metrics from the FRR routers and OVS switches in the GNS3 lab.

Prometheus does not scrape SNMP devices directly. The project uses Prometheus SNMP Exporter to convert SNMP data into Prometheus metrics.

## Current SNMP Scope

The current SNMP baseline monitors:

```text
5 FRR routers
6 OVS switches
11 total SNMP network devices
```

Current targets:

```text
core-frr-1     10.200.0.11:1161
core-frr-2     10.200.0.12:1161
dist-frr-1     10.200.0.21:1161
dist-frr-2     10.200.0.22:1161
edge-router    10.200.0.30:1161
dist-ovs-1     10.200.0.31:1161
dist-ovs-2     10.200.0.32:1161
dmz-ovs-3      10.200.0.33:1161
access-ovs-4   10.200.0.44:1161
access-ovs-5   10.200.0.45:1161
access-ovs-6   10.200.0.46:1161
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
FRR routers and OVS switches
        ↓ SNMPv3 authPriv on UDP/1161
SNMP Exporter on DevOps VM
        ↓ HTTP /snmp endpoint on localhost:9116
Prometheus
        ↓ HTTP API snapshot export
AWS S3
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
frr/snmp/templates/snmpd.conf.template
frr/snmp/env/frr-routers.snmp.env.example
ovs/snmp/templates/snmpd.conf.template
ovs/snmp/env/ovs-switches.snmp.env.example
docker/frr-ssh/start-snmp.sh
docker/ovs-ssh/start-snmp.sh
```

## Local-Only Files

Files that contain real secrets and must not be committed:

```text
monitoring/snmp/snmp-auth.local.yml
frr/snmp/env/frr-routers.snmp.env
ovs/snmp/env/ovs-switches.snmp.env
/etc/prometheus/snmp.yml
```

The local auth files contain the real SNMPv3 username and passwords.

The final `/etc/prometheus/snmp.yml` is generated locally and contains the official SNMP Exporter module configuration plus the local SNMPv3 auth profile.

## Device-Side SNMP Configuration

FRR and OVS containers start SNMP through:

```text
/start-snmp.sh
```

The script reads:

```text
/etc/local/snmp/snmp.env
/etc/local/snmp/snmpd.conf.template
```

The persistent GNS3 bootstrap copies the versioned templates and local secret env files into each managed network device.

FRR uses:

```text
frr/snmp/templates/snmpd.conf.template
frr/snmp/env/frr-routers.snmp.env
```

OVS uses:

```text
ovs/snmp/templates/snmpd.conf.template
ovs/snmp/env/ovs-switches.snmp.env
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
device_type
source=snmp
environment=gns3-onprem-lab
```

Example labels:

```text
device_type=frr-router
device_type=ovs-switch
```

## Building the Local SNMP Exporter Config

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
3. Keeps the generated IF-MIB module mappings.
4. Injects the local SNMPv3 auth profile.
5. Installs the final config to /etc/prometheus/snmp.yml.
6. Restarts prometheus-snmp-exporter.
7. Tests SNMP scraping through the exporter.
```

## Validation Commands

Test all SNMP network devices from the DevOps VM:

```bash
for target in \
  10.200.0.11 \
  10.200.0.12 \
  10.200.0.21 \
  10.200.0.22 \
  10.200.0.30 \
  10.200.0.31 \
  10.200.0.32 \
  10.200.0.33 \
  10.200.0.44 \
  10.200.0.45 \
  10.200.0.46
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

Expected result: each device returns its hostname.

Test Prometheus SNMP target health:

```bash
curl -fsS --get "http://localhost:9090/api/v1/query" \
  --data-urlencode 'query=up{job="snmp-network-devices"}' | python3 -m json.tool
```

Expected result:

```text
11 SNMP targets
11 targets up
```

Test SNMP interface metrics:

```bash
curl -fsS --get "http://localhost:9090/api/v1/query" \
  --data-urlencode 'query=ifOperStatus{job="snmp-network-devices"}' | python3 -m json.tool
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
Network device interface unexpectedly down
Interface errors detected
Traffic counters available for future trend analysis
```

## Interface Health Notes

The dashboard can display special/internal interfaces for visibility.

For anomaly scoring, these interfaces are ignored:

```text
lo
vrrp*
ovs-system
```

This avoids false alerts for loopback interfaces, VRRP backup virtual interfaces and the OVS internal system interface.

Health-relevant interfaces include:

```text
FRR physical and routed interfaces
FRR VLAN subinterfaces
OVS bridge interface br0
OVS management interface mgmt0
OVS physical/container interfaces eth*
```

## Do Not Commit

Never commit:

```text
monitoring/snmp/snmp-auth.local.yml
frr/snmp/env/frr-routers.snmp.env
ovs/snmp/env/ovs-switches.snmp.env
/etc/prometheus/snmp.yml
monitoring/outputs/
```
