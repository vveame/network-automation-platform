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

    ignored_exact = {
        "lo",
        "ovs-system",
    }

    ignored_prefixes = (
        "vrrp",
    )

    if if_name in ignored_exact:
        return False

    if if_name.startswith(ignored_prefixes):
        return False

    return True


def load_metric(metrics_dir: Path, filename: str) -> dict[str, Any] | None:
    return load_json(metrics_dir / filename)


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
                "device_type": metric.get("device_type", "unknown"),
                "status": "up" if value == 1 else "down",
            }
        )

    return targets


def parse_uname(uname_query: dict[str, Any] | None) -> dict[str, dict[str, str]]:
    by_instance = {}

    for item in result_items(uname_query):
        metric = item.get("metric", {})
        instance = metric.get("instance", "unknown")

        by_instance[instance] = {
            "system_name": metric.get("nodename", metric.get("sysname", "unknown")),
            "kernel_release": metric.get("release", "unknown"),
            "node_name": metric.get("node_name", metric.get("nodename", instance)),
            "role": metric.get("role", "unknown"),
        }

    return by_instance


def values_by_instance(query_data: dict[str, Any] | None) -> dict[str, float]:
    values = {}

    for item in result_items(query_data):
        metric = item.get("metric", {})
        instance = metric.get("instance", "unknown")
        values[instance] = item_value(item)

    return values


def parse_node_metrics(
    uname_query: dict[str, Any] | None,
    cpu_query: dict[str, Any] | None,
    load1_query: dict[str, Any] | None,
    load5_query: dict[str, Any] | None,
    load15_query: dict[str, Any] | None,
    memory_available_query: dict[str, Any] | None,
    memory_total_query: dict[str, Any] | None,
    disk_available_query: dict[str, Any] | None,
    disk_total_query: dict[str, Any] | None,
    filesystem_readonly_query: dict[str, Any] | None,
) -> list[dict[str, Any]]:
    uname_by_instance = parse_uname(uname_query)

    cpu_by_instance = values_by_instance(cpu_query)
    load1_by_instance = values_by_instance(load1_query)
    load5_by_instance = values_by_instance(load5_query)
    load15_by_instance = values_by_instance(load15_query)
    memory_available_by_instance = values_by_instance(memory_available_query)
    memory_total_by_instance = values_by_instance(memory_total_query)
    disk_available_by_instance = values_by_instance(disk_available_query)
    disk_total_by_instance = values_by_instance(disk_total_query)
    readonly_by_instance = values_by_instance(filesystem_readonly_query)

    instances = sorted(
        set(uname_by_instance.keys())
        | set(memory_total_by_instance.keys())
        | set(cpu_by_instance.keys())
        | set(load1_by_instance.keys())
    )

    nodes = []

    for instance in instances:
        uname = uname_by_instance.get(instance, {})

        memory_available = memory_available_by_instance.get(instance, 0)
        memory_total = memory_total_by_instance.get(instance, 0)
        disk_available = disk_available_by_instance.get(instance, 0)
        disk_total = disk_total_by_instance.get(instance, 0)

        node = {
            "instance": instance,
            "node_name": uname.get("node_name", instance),
            "role": uname.get("role", "unknown"),
            "system_name": uname.get("system_name", "unknown"),
            "kernel_release": uname.get("kernel_release", "unknown"),

            "cpu_usage_percent": round(cpu_by_instance.get(instance, 0.0), 2),
            "load1": round(load1_by_instance.get(instance, 0.0), 2),
            "load5": round(load5_by_instance.get(instance, 0.0), 2),
            "load15": round(load15_by_instance.get(instance, 0.0), 2),

            "memory_available_gb": round(memory_available / BYTES_IN_GB, 2) if memory_available else 0,
            "memory_total_gb": round(memory_total / BYTES_IN_GB, 2) if memory_total else 0,
            "memory_used_percent": used_percent(memory_available, memory_total),

            "disk_available_gb": round(disk_available / BYTES_IN_GB, 2) if disk_available else 0,
            "disk_total_gb": round(disk_total / BYTES_IN_GB, 2) if disk_total else 0,
            "disk_used_percent": used_percent(disk_available, disk_total),

            "filesystem_readonly": readonly_by_instance.get(instance, 0) == 1,
        }

        nodes.append(node)

    return nodes


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
    dns_lookup_query: dict[str, Any] | None,
) -> list[dict[str, Any]]:
    duration_by_key = values_by_blackbox_key(duration_query)
    http_status_by_key = values_by_blackbox_key(http_status_query)
    dns_lookup_by_key = values_by_blackbox_key(dns_lookup_query)

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
                "dns_lookup_time_seconds": round(dns_lookup_by_key.get(key, 0.0), 4),
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
    in_octets_rate_query: dict[str, Any] | None,
    out_octets_rate_query: dict[str, Any] | None,
    in_errors_query: dict[str, Any] | None,
    out_errors_query: dict[str, Any] | None,
    in_errors_rate_query: dict[str, Any] | None,
    out_errors_rate_query: dict[str, Any] | None,
    in_discards_query: dict[str, Any] | None,
    out_discards_query: dict[str, Any] | None,
    in_discards_rate_query: dict[str, Any] | None,
    out_discards_rate_query: dict[str, Any] | None,
    if_speed_query: dict[str, Any] | None,
    if_high_speed_query: dict[str, Any] | None,
    if_mtu_query: dict[str, Any] | None,
) -> list[dict[str, Any]]:
    admin_by_key = values_by_snmp_interface_key(admin_query)
    in_octets_by_key = values_by_snmp_interface_key(in_octets_query)
    out_octets_by_key = values_by_snmp_interface_key(out_octets_query)
    in_octets_rate_by_key = values_by_snmp_interface_key(in_octets_rate_query)
    out_octets_rate_by_key = values_by_snmp_interface_key(out_octets_rate_query)
    in_errors_by_key = values_by_snmp_interface_key(in_errors_query)
    out_errors_by_key = values_by_snmp_interface_key(out_errors_query)
    in_errors_rate_by_key = values_by_snmp_interface_key(in_errors_rate_query)
    out_errors_rate_by_key = values_by_snmp_interface_key(out_errors_rate_query)
    in_discards_by_key = values_by_snmp_interface_key(in_discards_query)
    out_discards_by_key = values_by_snmp_interface_key(out_discards_query)
    in_discards_rate_by_key = values_by_snmp_interface_key(in_discards_rate_query)
    out_discards_rate_by_key = values_by_snmp_interface_key(out_discards_rate_query)
    if_speed_by_key = values_by_snmp_interface_key(if_speed_query)
    if_high_speed_by_key = values_by_snmp_interface_key(if_high_speed_query)
    if_mtu_by_key = values_by_snmp_interface_key(if_mtu_query)

    interfaces = []

    for item in result_items(oper_query):
        metric = item.get("metric", {})
        key = snmp_interface_key(metric)

        if_name = metric.get("ifName", metric.get("ifDescr", "unknown"))
        admin_value = int(admin_by_key.get(key, 0))
        oper_value = int(item_value(item))

        in_errors = int(in_errors_by_key.get(key, 0))
        out_errors = int(out_errors_by_key.get(key, 0))
        in_discards = int(in_discards_by_key.get(key, 0))
        out_discards = int(out_discards_by_key.get(key, 0))

        in_bps = in_octets_rate_by_key.get(key, 0.0) * 8
        out_bps = out_octets_rate_by_key.get(key, 0.0) * 8

        in_error_rate = in_errors_rate_by_key.get(key, 0.0)
        out_error_rate = out_errors_rate_by_key.get(key, 0.0)
        in_discard_rate = in_discards_rate_by_key.get(key, 0.0)
        out_discard_rate = out_discards_rate_by_key.get(key, 0.0)

        interfaces.append(
            {
                "node_name": metric.get("node_name", metric.get("instance", "unknown")),
                "instance": metric.get("instance", "unknown"),
                "role": metric.get("role", "unknown"),
                "device_type": metric.get("device_type", "unknown"),
                "if_name": if_name,
                "if_descr": metric.get("ifDescr", "unknown"),
                "if_index": metric.get("ifIndex", "unknown"),

                "admin_status": SNMP_STATUS_MAP.get(admin_value, f"unknown_{admin_value}"),
                "oper_status": SNMP_STATUS_MAP.get(oper_value, f"unknown_{oper_value}"),
                "health_relevant": is_health_relevant_snmp_interface(if_name),

                "in_octets": int(in_octets_by_key.get(key, 0)),
                "out_octets": int(out_octets_by_key.get(key, 0)),
                "in_bps": round(in_bps, 2),
                "out_bps": round(out_bps, 2),

                "in_errors": in_errors,
                "out_errors": out_errors,
                "total_errors": in_errors + out_errors,
                "in_error_rate": round(in_error_rate, 4),
                "out_error_rate": round(out_error_rate, 4),
                "total_error_rate": round(in_error_rate + out_error_rate, 4),

                "in_discards": in_discards,
                "out_discards": out_discards,
                "total_discards": in_discards + out_discards,
                "in_discard_rate": round(in_discard_rate, 4),
                "out_discard_rate": round(out_discard_rate, 4),
                "total_discard_rate": round(in_discard_rate + out_discard_rate, 4),

                "if_speed_bps": int(if_speed_by_key.get(key, 0)),
                "if_high_speed_mbps": int(if_high_speed_by_key.get(key, 0)),
                "if_mtu": int(if_mtu_by_key.get(key, 0)),
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

    manifest = load_metric(metrics_dir, "manifest.json")
    up_query = load_metric(metrics_dir, "up.json")

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

    node_metrics = parse_node_metrics(
        uname_query=load_metric(metrics_dir, "node_uname_info.json"),
        cpu_query=load_metric(metrics_dir, "node_cpu_usage_percent.json"),
        load1_query=load_metric(metrics_dir, "node_load1.json"),
        load5_query=load_metric(metrics_dir, "node_load5.json"),
        load15_query=load_metric(metrics_dir, "node_load15.json"),
        memory_available_query=load_metric(metrics_dir, "node_memory_available_bytes.json"),
        memory_total_query=load_metric(metrics_dir, "node_memory_total_bytes.json"),
        disk_available_query=load_metric(metrics_dir, "node_filesystem_available_bytes.json"),
        disk_total_query=load_metric(metrics_dir, "node_filesystem_size_bytes.json"),
        filesystem_readonly_query=load_metric(metrics_dir, "node_filesystem_readonly.json"),
    )

    memory_available = sum(node["memory_available_gb"] for node in node_metrics)
    memory_total = sum(node["memory_total_gb"] for node in node_metrics)
    disk_available = sum(node["disk_available_gb"] for node in node_metrics)
    disk_total = sum(node["disk_total_gb"] for node in node_metrics)

    memory_used = used_percent(memory_available, memory_total)
    disk_used = used_percent(disk_available, disk_total)
    max_cpu_usage = max([node["cpu_usage_percent"] for node in node_metrics], default=0.0)
    max_load1 = max([node["load1"] for node in node_metrics], default=0.0)
    readonly_count = len([node for node in node_metrics if node["filesystem_readonly"]])

    blackbox_probes = parse_blackbox_probes(
        success_query=load_metric(metrics_dir, "blackbox_probe_success.json"),
        duration_query=load_metric(metrics_dir, "blackbox_probe_duration_seconds.json"),
        http_status_query=load_metric(metrics_dir, "blackbox_http_status_code.json"),
        dns_lookup_query=load_metric(metrics_dir, "blackbox_dns_lookup_time_seconds.json"),
    )

    blackbox_total = len(blackbox_probes)
    blackbox_success = len([probe for probe in blackbox_probes if probe["status"] == "success"])
    blackbox_failed = max(blackbox_total - blackbox_success, 0)
    blackbox_max_duration = max([probe["duration_seconds"] for probe in blackbox_probes], default=0.0)

    snmp_targets = parse_targets(load_metric(metrics_dir, "snmp_up.json"))
    snmp_targets_total = len(snmp_targets)
    snmp_targets_up = len([target for target in snmp_targets if target["status"] == "up"])
    snmp_targets_down = max(snmp_targets_total - snmp_targets_up, 0)

    snmp_interfaces = parse_snmp_interfaces(
        admin_query=load_metric(metrics_dir, "snmp_if_admin_status.json"),
        oper_query=load_metric(metrics_dir, "snmp_if_oper_status.json"),
        in_octets_query=load_metric(metrics_dir, "snmp_if_hc_in_octets.json"),
        out_octets_query=load_metric(metrics_dir, "snmp_if_hc_out_octets.json"),
        in_octets_rate_query=load_metric(metrics_dir, "snmp_if_hc_in_octets_rate_5m.json"),
        out_octets_rate_query=load_metric(metrics_dir, "snmp_if_hc_out_octets_rate_5m.json"),
        in_errors_query=load_metric(metrics_dir, "snmp_if_in_errors.json"),
        out_errors_query=load_metric(metrics_dir, "snmp_if_out_errors.json"),
        in_errors_rate_query=load_metric(metrics_dir, "snmp_if_in_errors_rate_5m.json"),
        out_errors_rate_query=load_metric(metrics_dir, "snmp_if_out_errors_rate_5m.json"),
        in_discards_query=load_metric(metrics_dir, "snmp_if_in_discards.json"),
        out_discards_query=load_metric(metrics_dir, "snmp_if_out_discards.json"),
        in_discards_rate_query=load_metric(metrics_dir, "snmp_if_in_discards_rate_5m.json"),
        out_discards_rate_query=load_metric(metrics_dir, "snmp_if_out_discards_rate_5m.json"),
        if_speed_query=load_metric(metrics_dir, "snmp_if_speed.json"),
        if_high_speed_query=load_metric(metrics_dir, "snmp_if_high_speed.json"),
        if_mtu_query=load_metric(metrics_dir, "snmp_if_mtu.json"),
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

    snmp_interfaces_with_error_rate = [
        iface
        for iface in health_interfaces
        if iface["total_error_rate"] > 0
    ]

    snmp_interfaces_with_discards = [
        iface
        for iface in health_interfaces
        if iface["total_discards"] > 0
    ]

    snmp_interfaces_with_discard_rate = [
        iface
        for iface in health_interfaces
        if iface["total_discard_rate"] > 0
    ]

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

        "node_metrics": node_metrics,
        "memory_available_gb": round(memory_available, 2),
        "memory_total_gb": round(memory_total, 2),
        "memory_used_percent": memory_used,
        "disk_available_gb": round(disk_available, 2),
        "disk_total_gb": round(disk_total, 2),
        "disk_used_percent": disk_used,
        "max_cpu_usage_percent": round(max_cpu_usage, 2),
        "max_load1": round(max_load1, 2),
        "filesystem_readonly_count": readonly_count,

        "blackbox_probes_total": blackbox_total,
        "blackbox_probes_success": blackbox_success,
        "blackbox_probes_failed": blackbox_failed,
        "blackbox_max_duration_seconds": round(blackbox_max_duration, 4),
        "blackbox_probes": blackbox_probes,

        "snmp_available": snmp_targets_total > 0 or len(snmp_interfaces) > 0,
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
        "snmp_interfaces_with_error_rate_count": len(snmp_interfaces_with_error_rate),
        "snmp_interfaces_with_error_rate": snmp_interfaces_with_error_rate,

        "snmp_interfaces_with_discards_count": len(snmp_interfaces_with_discards),
        "snmp_interfaces_with_discards": snmp_interfaces_with_discards,
        "snmp_interfaces_with_discard_rate_count": len(snmp_interfaces_with_discard_rate),
        "snmp_interfaces_with_discard_rate": snmp_interfaces_with_discard_rate,

        "snmp_interfaces_all": snmp_interfaces,
        "snmp_interfaces": health_interfaces,
    }
