#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
LOCAL_DASH_DIR="$REPO_ROOT/monitoring/grafana/dashboards"
CLOUD_DASH_DIR="$REPO_ROOT/cloud/monitoring/grafana/dashboards"
CLOUD_PROV_DIR="$REPO_ROOT/cloud/monitoring/grafana/provisioning"

mkdir -p "$CLOUD_DASH_DIR"
mkdir -p "$CLOUD_PROV_DIR/dashboards"
mkdir -p "$CLOUD_PROV_DIR/datasources"

LOCAL_OVERVIEW="$LOCAL_DASH_DIR/pfe-local-monitoring-overview.json"
LOCAL_NETWORK="$LOCAL_DASH_DIR/pfe-network-devices-interfaces.json"

CLOUD_OVERVIEW="$CLOUD_DASH_DIR/pfe-cloud-monitoring-overview.json"
CLOUD_NETWORK="$CLOUD_DASH_DIR/pfe-cloud-network-devices-interfaces.json"

for file in "$LOCAL_OVERVIEW" "$LOCAL_NETWORK"; do
  if [ ! -f "$file" ]; then
    echo "[ERROR] Missing dashboard: $file"
    exit 1
  fi
done

BACKUP_DIR="$REPO_ROOT/.dashboard-backups/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$BACKUP_DIR"

cp "$LOCAL_OVERVIEW" "$BACKUP_DIR/"
cp "$LOCAL_NETWORK" "$BACKUP_DIR/"

echo "[INFO] Backed up current dashboards to: $BACKUP_DIR"

python3 - <<'PY'
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

repo = Path.cwd()

local_files = [
    repo / "monitoring/grafana/dashboards/pfe-local-monitoring-overview.json",
    repo / "monitoring/grafana/dashboards/pfe-network-devices-interfaces.json",
]

cloud_map = {
    repo / "monitoring/grafana/dashboards/pfe-local-monitoring-overview.json":
        repo / "cloud/monitoring/grafana/dashboards/pfe-cloud-monitoring-overview.json",
    repo / "monitoring/grafana/dashboards/pfe-network-devices-interfaces.json":
        repo / "cloud/monitoring/grafana/dashboards/pfe-cloud-network-devices-interfaces.json",
}

LOCAL_REPLACEMENTS = {
    "cloud-blackbox-http-through-tunnel|cloud-blackbox-tcp-through-tunnel|cloud-blackbox-dns-through-tunnel":
        "blackbox-http|blackbox-tcp|blackbox-dns",

    'job=~"cloud-node-exporter|local-node-exporter-through-tunnel"':
        'job="node-exporter"',

    'job="cloud-snmp-network-devices-through-tunnel"':
        'job="snmp-network-devices"',

    'node=~"$device"':
        'node_name=~"$device"',

    "{{node}}":
        "{{node_name}}",

    "{{service}}":
        "{{service_name}}",

    'label_values(up{job="snmp-network-devices"}, node)':
        'label_values(up{job="snmp-network-devices"}, node_name)',
}

CLOUD_REPLACEMENTS = {
    "blackbox-http|blackbox-tcp|blackbox-dns":
        "cloud-blackbox-http-through-tunnel|cloud-blackbox-tcp-through-tunnel|cloud-blackbox-dns-through-tunnel",

    'job="node-exporter"':
        'job=~"cloud-node-exporter|local-node-exporter-through-tunnel"',

    'job="snmp-network-devices"':
        'job="cloud-snmp-network-devices-through-tunnel"',

    'node_name=~"$device"':
        'node=~"$device"',

    "{{node_name}}":
        "{{node}}",

    "{{service_name}}":
        "{{service}}",

    'label_values(up{job="cloud-snmp-network-devices-through-tunnel"}, node_name)':
        'label_values(up{job="cloud-snmp-network-devices-through-tunnel"}, node)',

    'label_values(up{job="snmp-network-devices"}, node_name)':
        'label_values(up{job="cloud-snmp-network-devices-through-tunnel"}, node)',
}


def replace_in_obj(obj: Any, replacements: dict[str, str]) -> Any:
    if isinstance(obj, dict):
        return {k: replace_in_obj(v, replacements) for k, v in obj.items()}

    if isinstance(obj, list):
        return [replace_in_obj(v, replacements) for v in obj]

    if isinstance(obj, str):
        for old, new in replacements.items():
            obj = obj.replace(old, new)
        return obj

    return obj


def normalize_variable_all_value(data: dict[str, Any], label_name: str) -> None:
    templating = data.get("templating", {})
    for item in templating.get("list", []):
        if item.get("name") == "device":
            item["includeAll"] = True
            item["allValue"] = ".*"
            item["current"] = {
                "selected": True,
                "text": "All",
                "value": ".*",
            }

            query = item.get("query")
            if isinstance(query, str):
                if "label_values" in query:
                    if "cloud-snmp-network-devices-through-tunnel" in query:
                        item["query"] = 'label_values(up{job="cloud-snmp-network-devices-through-tunnel"}, node)'
                    else:
                        item["query"] = f'label_values(up{{job="snmp-network-devices"}}, {label_name})'

            definition = item.get("definition")
            if isinstance(definition, str):
                if "cloud-snmp-network-devices-through-tunnel" in definition:
                    item["definition"] = 'label_values(up{job="cloud-snmp-network-devices-through-tunnel"}, node)'
                else:
                    item["definition"] = f'label_values(up{{job="snmp-network-devices"}}, {label_name})'


def load_json(path: Path) -> dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"[ERROR] Invalid JSON before patch: {path}: {exc}") from exc


def save_json(path: Path, data: dict[str, Any]) -> None:
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    json.loads(path.read_text(encoding="utf-8"))


# 1) Restore local dashboards to local job names / local labels.
for path in local_files:
    data = load_json(path)
    data = replace_in_obj(data, LOCAL_REPLACEMENTS)

    title = data.get("title", "")
    if "Cloud" in title:
        data["title"] = title.replace("Cloud", "Local")

    if path.name == "pfe-local-monitoring-overview.json":
        data["title"] = "PFE - Local Monitoring Overview"
        data["uid"] = "pfe-local-monitoring-overview"

    if path.name == "pfe-network-devices-interfaces.json":
        data["title"] = "PFE - Network Devices & Interfaces"
        data["uid"] = "pfe-network-devices-interfaces"
        normalize_variable_all_value(data, "node_name")

    save_json(path, data)
    print(f"[OK] restored local dashboard: {path}")


# 2) Create separate cloud dashboards from the restored local dashboards.
for local_path, cloud_path in cloud_map.items():
    data = load_json(local_path)
    data = replace_in_obj(data, CLOUD_REPLACEMENTS)

    if local_path.name == "pfe-local-monitoring-overview.json":
        data["title"] = "PFE - Cloud Monitoring Overview"
        data["uid"] = "pfe-cloud-monitoring-overview"

    if local_path.name == "pfe-network-devices-interfaces.json":
        data["title"] = "PFE - Cloud Network Devices & Interfaces"
        data["uid"] = "pfe-cloud-network-devices-interfaces"
        normalize_variable_all_value(data, "node")

    # Optional visual tag separation.
    tags = data.get("tags")
    if not isinstance(tags, list):
        tags = []
    for tag in ["pfe", "cloud-monitoring", "aws"]:
        if tag not in tags:
            tags.append(tag)
    data["tags"] = tags

    save_json(cloud_path, data)
    print(f"[OK] generated cloud dashboard: {cloud_path}")


# 3) Validate all dashboard JSON files.
for path in [
    repo / "monitoring/grafana/dashboards/pfe-local-monitoring-overview.json",
    repo / "monitoring/grafana/dashboards/pfe-network-devices-interfaces.json",
    repo / "cloud/monitoring/grafana/dashboards/pfe-cloud-monitoring-overview.json",
    repo / "cloud/monitoring/grafana/dashboards/pfe-cloud-network-devices-interfaces.json",
]:
    load_json(path)
    print(f"[OK] valid JSON: {path}")
PY

cat > "$CLOUD_PROV_DIR/dashboards/pfe-cloud-dashboards.yml" <<'EOF_PROV'
apiVersion: 1

providers:
  - name: pfe-cloud-monitoring-dashboards
    orgId: 1
    folder: PFE Cloud Monitoring
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards/pfe-cloud
EOF_PROV

cat > "$CLOUD_PROV_DIR/datasources/prometheus-cloud.yml" <<'EOF_DS'
apiVersion: 1

datasources:
  - name: Prometheus
    uid: prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
    editable: true
    jsonData:
      timeInterval: 15s
EOF_DS

echo "[OK] Created cloud Grafana provisioning files."
echo
echo "[INFO] Local dashboards restored under:"
echo "  monitoring/grafana/dashboards/"
echo
echo "[INFO] Cloud dashboards generated under:"
echo "  cloud/monitoring/grafana/dashboards/"
echo
echo "[INFO] Cloud provisioning generated under:"
echo "  cloud/monitoring/grafana/provisioning/"
