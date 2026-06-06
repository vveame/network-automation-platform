from __future__ import annotations

import json
from pathlib import Path
from typing import Any


BYTES_IN_GB = 1024 ** 3

SNMP_STATUS_MAP = {
    1: "up",
    2: "down",
    3: "testing",
    4: "unknown",
    5: "dormant",
    6: "not_present",
    7: "lower_layer_down",
}


def load_json(path: Path) -> dict[str, Any] | None:
    if not path.exists() or not path.is_file():
        return None

    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None


def result_items(query_data: dict[str, Any] | None) -> list[dict[str, Any]]:
    if not query_data:
        return []

    return query_data.get("data", {}).get("result", [])


def item_value(item: dict[str, Any]) -> float:
    try:
        return float(item.get("value", [0, "0"])[1])
    except (ValueError, TypeError, IndexError):
        return 0.0


def first_value(query_data: dict[str, Any] | None) -> float:
    items = result_items(query_data)

    if not items:
        return 0.0

    return item_value(items[0])


def used_percent(available: float, total: float) -> float:
    if not total:
        return 0.0

    used = max(total - available, 0)
    return round((used / total) * 100, 2)


def is_health_relevant_snmp_interface(if_name: str) -> bool:
    if not if_name:
        return False

    if if_name == "lo":
        return False

    if if_name.startswith("vrrp"):
        return False

    return True


def parse_targets(up_query: dict[str, Any] | None) -> list[dict[str, str]]:
    targets = []

    for item in result_items(up_query):
        metric = item.get("metric", {})
        value = item_value(item)

        targets.append(
            {
                "job": metric.get("job", "unknown"),
                "instance": metric.get("instance", "unknown"),
                "node_name": metric.get("node_name", "unknown"),
                "role": metric.get("role", "unknown"),
                "status": "up" if value == 1 else "down",
            }
        )

    return targets


def parse_uname(uname_query: dict[str, Any] | None) -> dict[str, str]:
    items = result_items(uname_query)

    if not items:
        return {
            "system_name": "unknown",
            "kernel_release": "unknown",
        }

    metric = items[0].get("metric", {})

    return {
        "system_name": metric.get("nodename", metric.get("sysname", "unknown")),
        "kernel_release": metric.get("release", "unknown"),
    }


def blackbox_key(metric: dict[str, Any]) -> tuple[str, str, str]:
    return (
        metric.get("job", "unknown"),
        metric.get("instance", "unknown"),
        metric.get("service_name", "unknown"),
    )


def values_by_blackbox_key(query_data: dict[str, Any] | None) -> dict[tuple[str, str, str], float]:
    values = {}

    for item in result_items(query_data):
        metric = item.get("metric", {})
        values[blackbox_key(metric)] = item_value(item)

    return values


def parse_blackbox_probes(
    success_query: dict[str, Any] | None,
    duration_query: dict[str, Any] | None,
    http_status_query: dict[str, Any] | None,
) -> list[dict[str, Any]]:
    duration_by_key = values_by_blackbox_key(duration_query)
    http_status_by_key = values_by_blackbox_key(http_status_query)

    probes = []

    for item in result_items(success_query):
        metric = item.get("metric", {})
        value = item_value(item)
        key = blackbox_key(metric)

        probes.append(
            {
                "service_name": metric.get("service_name", metric.get("instance", "unknown")),
                "job": metric.get("job", "unknown"),
                "instance": metric.get("instance", "unknown"),
                "role": metric.get("role", "unknown"),
                "probe_type": metric.get("probe_type", "unknown"),
                "status": "success" if value == 1 else "failed",
                "duration_seconds": round(duration_by_key.get(key, 0.0), 4),
                "http_status_code": int(http_status_by_key.get(key, 0)),
            }
        )

    return sorted(probes, key=lambda probe: probe["service_name"])


def snmp_interface_key(metric: dict[str, Any]) -> tuple[str, str, str]:
    return (
        metric.get("instance", "unknown"),
        metric.get("ifIndex", "unknown"),
        metric.get("ifName", metric.get("ifDescr", "unknown")),
    )


def values_by_snmp_interface_key(
    query_data: dict[str, Any] | None,
) -> dict[tuple[str, str, str], float]:
    values = {}

    for item in result_items(query_data):
        metric = item.get("metric", {})
        values[snmp_interface_key(metric)] = item_value(item)

    return values


def parse_snmp_interfaces(
    admin_query: dict[str, Any] | None,
    oper_query: dict[str, Any] | None,
    in_octets_query: dict[str, Any] | None,
    out_octets_query: dict[str, Any] | None,
    in_errors_query: dict[str, Any] | None,
    out_errors_query: dict[str, Any] | None,
) -> list[dict[str, Any]]:
    admin_by_key = values_by_snmp_interface_key(admin_query)
    in_octets_by_key = values_by_snmp_interface_key(in_octets_query)
    out_octets_by_key = values_by_snmp_interface_key(out_octets_query)
    in_errors_by_key = values_by_snmp_interface_key(in_errors_query)
    out_errors_by_key = values_by_snmp_interface_key(out_errors_query)

    interfaces = []

    for item in result_items(oper_query):
        metric = item.get("metric", {})
        key = snmp_interface_key(metric)

        if_name = metric.get("ifName", metric.get("ifDescr", "unknown"))
        admin_value = int(admin_by_key.get(key, 0))
        oper_value = int(item_value(item))

        in_errors = int(in_errors_by_key.get(key, 0))
        out_errors = int(out_errors_by_key.get(key, 0))

        interfaces.append(
            {
                "node_name": metric.get("node_name", metric.get("instance", "unknown")),
                "instance": metric.get("instance", "unknown"),
                "role": metric.get("role", "unknown"),
                "if_name": if_name,
                "if_descr": metric.get("ifDescr", "unknown"),
                "if_index": metric.get("ifIndex", "unknown"),
                "admin_status": SNMP_STATUS_MAP.get(admin_value, f"unknown_{admin_value}"),
                "oper_status": SNMP_STATUS_MAP.get(oper_value, f"unknown_{oper_value}"),
                "health_relevant": is_health_relevant_snmp_interface(if_name),
                "in_octets": int(in_octets_by_key.get(key, 0)),
                "out_octets": int(out_octets_by_key.get(key, 0)),
                "in_errors": in_errors,
                "out_errors": out_errors,
                "total_errors": in_errors + out_errors,
            }
        )

    return sorted(interfaces, key=lambda iface: (iface["node_name"], iface["if_name"]))


def parse_prometheus_metrics(metrics_dir: Path | None) -> dict[str, Any]:
    if not metrics_dir:
        return {
            "available": False,
            "reason": "metrics_dir_not_provided",
        }

    if not metrics_dir.exists() or not metrics_dir.is_dir():
        return {
            "available": False,
            "reason": f"metrics_dir_not_found: {metrics_dir}",
        }

    manifest = load_json(metrics_dir / "manifest.json")
    up_query = load_json(metrics_dir / "up.json")

    uname_query = load_json(metrics_dir / "node_uname_info.json")
    memory_available_query = load_json(metrics_dir / "node_memory_available_bytes.json")
    memory_total_query = load_json(metrics_dir / "node_memory_total_bytes.json")
    disk_available_query = load_json(metrics_dir / "node_filesystem_available_bytes.json")
    disk_total_query = load_json(metrics_dir / "node_filesystem_size_bytes.json")

    blackbox_success_query = load_json(metrics_dir / "blackbox_probe_success.json")
    blackbox_duration_query = load_json(metrics_dir / "blackbox_probe_duration_seconds.json")
    blackbox_http_status_query = load_json(metrics_dir / "blackbox_http_status_code.json")

    snmp_up_query = load_json(metrics_dir / "snmp_up.json")
    snmp_sys_uptime_query = load_json(metrics_dir / "snmp_sys_uptime.json")
    snmp_admin_query = load_json(metrics_dir / "snmp_if_admin_status.json")
    snmp_oper_query = load_json(metrics_dir / "snmp_if_oper_status.json")
    snmp_in_octets_query = load_json(metrics_dir / "snmp_if_hc_in_octets.json")
    snmp_out_octets_query = load_json(metrics_dir / "snmp_if_hc_out_octets.json")
    snmp_in_errors_query = load_json(metrics_dir / "snmp_if_in_errors.json")
    snmp_out_errors_query = load_json(metrics_dir / "snmp_if_out_errors.json")

    if not manifest or not up_query:
        return {
            "available": False,
            "reason": "required_metrics_files_missing",
            "metrics_dir": str(metrics_dir),
        }

    targets = parse_targets(up_query)
    targets_total = len(targets)
    targets_up = len([target for target in targets if target["status"] == "up"])
    targets_down = max(targets_total - targets_up, 0)

    memory_available = first_value(memory_available_query)
    memory_total = first_value(memory_total_query)
    disk_available = first_value(disk_available_query)
    disk_total = first_value(disk_total_query)

    memory_used = used_percent(memory_available, memory_total)
    disk_used = used_percent(disk_available, disk_total)

    uname = parse_uname(uname_query)

    blackbox_probes = parse_blackbox_probes(
        success_query=blackbox_success_query,
        duration_query=blackbox_duration_query,
        http_status_query=blackbox_http_status_query,
    )

    blackbox_total = len(blackbox_probes)
    blackbox_success = len([probe for probe in blackbox_probes if probe["status"] == "success"])
    blackbox_failed = max(blackbox_total - blackbox_success, 0)

    snmp_targets = parse_targets(snmp_up_query)
    snmp_targets_total = len(snmp_targets)
    snmp_targets_up = len([target for target in snmp_targets if target["status"] == "up"])
    snmp_targets_down = max(snmp_targets_total - snmp_targets_up, 0)

    snmp_interfaces = parse_snmp_interfaces(
        admin_query=snmp_admin_query,
        oper_query=snmp_oper_query,
        in_octets_query=snmp_in_octets_query,
        out_octets_query=snmp_out_octets_query,
        in_errors_query=snmp_in_errors_query,
        out_errors_query=snmp_out_errors_query,
    )

    health_interfaces = [
        iface for iface in snmp_interfaces if iface["health_relevant"]
    ]

    snmp_interfaces_total = len(health_interfaces)
    snmp_interfaces_up = len(
        [iface for iface in health_interfaces if iface["oper_status"] == "up"]
    )
    snmp_interfaces_down = len(
        [iface for iface in health_interfaces if iface["oper_status"] != "up"]
    )

    snmp_interfaces_unexpected_down = [
        iface
        for iface in health_interfaces
        if iface["admin_status"] == "up" and iface["oper_status"] != "up"
    ]

    snmp_interfaces_with_errors = [
        iface
        for iface in health_interfaces
        if iface["total_errors"] > 0
    ]

    snmp_sys_uptime = first_value(snmp_sys_uptime_query)

    return {
        "available": True,
        "source": "prometheus_metrics_snapshot",
        "metrics_dir": str(metrics_dir),
        "snapshot_time_utc": manifest.get("export_time_utc", "unknown"),
        "prometheus_url": manifest.get("prometheus_url", "unknown"),

        "targets_total": targets_total,
        "targets_up": targets_up,
        "targets_down": targets_down,
        "targets": targets,

        "memory_available_gb": round(memory_available / BYTES_IN_GB, 2) if memory_available else 0,
        "memory_total_gb": round(memory_total / BYTES_IN_GB, 2) if memory_total else 0,
        "memory_used_percent": memory_used,

        "disk_available_gb": round(disk_available / BYTES_IN_GB, 2) if disk_available else 0,
        "disk_total_gb": round(disk_total / BYTES_IN_GB, 2) if disk_total else 0,
        "disk_used_percent": disk_used,

        "system_name": uname["system_name"],
        "kernel_release": uname["kernel_release"],

        "blackbox_probes_total": blackbox_total,
        "blackbox_probes_success": blackbox_success,
        "blackbox_probes_failed": blackbox_failed,
        "blackbox_probes": blackbox_probes,

        "snmp_available": snmp_targets_total > 0 or len(snmp_interfaces) > 0,
        "snmp_sys_uptime": snmp_sys_uptime,
        "snmp_targets_total": snmp_targets_total,
        "snmp_targets_up": snmp_targets_up,
        "snmp_targets_down": snmp_targets_down,
        "snmp_targets": snmp_targets,

        "snmp_interfaces_total": snmp_interfaces_total,
        "snmp_interfaces_up": snmp_interfaces_up,
        "snmp_interfaces_down": snmp_interfaces_down,
        "snmp_interfaces_unexpected_down_count": len(snmp_interfaces_unexpected_down),
        "snmp_interfaces_unexpected_down": snmp_interfaces_unexpected_down,
        "snmp_interfaces_with_errors_count": len(snmp_interfaces_with_errors),
        "snmp_interfaces_with_errors": snmp_interfaces_with_errors,

        # Full list remains available for dashboard/debug output.
        "snmp_interfaces_all": snmp_interfaces,
        "snmp_interfaces": health_interfaces,
    }
