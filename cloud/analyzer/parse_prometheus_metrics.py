from __future__ import annotations

import json
from pathlib import Path
from typing import Any


BYTES_IN_GB = 1024 ** 3


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


def parse_targets(up_query: dict[str, Any] | None) -> list[dict[str, str]]:
    targets = []

    for item in result_items(up_query):
        metric = item.get("metric", {})
        value = item_value(item)

        targets.append(
            {
                "job": metric.get("job", "unknown"),
                "instance": metric.get("instance", "unknown"),
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
    }
