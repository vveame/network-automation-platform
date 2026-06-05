# Exporters

This directory documents exporters used by the monitoring layer.

## Current Exporter

### Node Exporter

Node Exporter exposes Linux host metrics to Prometheus.

Current target:

```text
devops-server:9100
```

The first baseline monitors the DevOps VM itself.

## Planned Exporters

Future exporters may include:

* Node Exporter on the GNS3 VM
* SNMP Exporter for network device metrics
* Blackbox Exporter for HTTP/DNS/ICMP service checks
* custom exporters for validation or anomaly status

## Notes

Exporters expose metrics. Prometheus scrapes those metrics and stores them as time-series data.
