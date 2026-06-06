# SNMP Exporter Configuration

This directory documents the SNMP monitoring workflow used by the local Prometheus baseline.

## Purpose

SNMP is used to collect network-device interface metrics from the FRR edge router.

The current SNMP monitored device is:

```text
EdgeRouter-VPNGateway
SNMP target: 10.200.0.30:1161
Prometheus job: snmp-network-devices
SNMP Exporter auth: pfe_snmpv3_authpriv
SNMP Exporter module: if_mib
```
## Why SNMP Exporter

Prometheus does not scrape SNMP devices directly.

The workflow is:

```text
EdgeRouter-VPNGateway
        ↓ SNMPv3 authPriv
SNMP Exporter on DevOps VM
        ↓ HTTP /snmp endpoint
Prometheus
        ↓ exported snapshot
S3
        ↓ dashboard cache
Flask dashboard + analyzer
```

SNMP Exporter converts SNMP interface data into Prometheus metrics.

## Security Model

The project uses SNMPv3 with authPriv.

```text
Authentication: SHA
Privacy/encryption: AES
Access type: read-only
SNMP port: UDP/1161
Allowed source: DevOps OOB IP 10.200.0.10
```

The SNMPv3 credentials are not committed to GitHub.

## Configuration Workflow

The local SNMP Exporter config is built by:

```bash
./monitoring/scripts/build-local-snmp-exporter-config.sh
```

The script does the following:

```text
1. Checks for local SNMPv3 credentials.
2. Downloads the official generated SNMP Exporter configuration.
3. Removes the default auth block.
4. Injects the local SNMPv3 auth block.
5. Installs the final config into /etc/prometheus/snmp.yml.
6. Restarts prometheus-snmp-exporter.
7. Tests the edge-router SNMP scrape.
```

## Validation Commands

Test SNMP Exporter directly:

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

These metrics are enough for the first anomaly-detection baseline:

```text
SNMP target down
Interface unexpectedly down
Interface errors detected
Traffic counters available for future trend analysis
```
