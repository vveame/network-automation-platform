from dto.prometheus_metrics_dto import PrometheusMetricsDTO, PrometheusTargetDTO


BYTES_IN_GB = 1024 ** 3


class PrometheusMetricsService:
    def __init__(self, prometheus_metrics_repository):
        self.repository = prometheus_metrics_repository

    def get_latest_metrics(self) -> PrometheusMetricsDTO:
        manifest = self.repository.load_manifest()
        up_query = self.repository.load_query("up")
        uname_query = self.repository.load_query("node_uname_info")
        memory_available_query = self.repository.load_query("node_memory_available_bytes")
        memory_total_query = self.repository.load_query("node_memory_total_bytes")
        disk_available_query = self.repository.load_query("node_filesystem_available_bytes")
        disk_total_query = self.repository.load_query("node_filesystem_size_bytes")

        if not manifest or not up_query:
            return self._unavailable()

        targets = self._parse_targets(up_query)
        targets_total = len(targets)
        targets_up = len([target for target in targets if target.status == "up"])
        targets_down = max(targets_total - targets_up, 0)

        memory_available = self._first_value(memory_available_query)
        memory_total = self._first_value(memory_total_query)
        disk_available = self._first_value(disk_available_query)
        disk_total = self._first_value(disk_total_query)

        memory_used_percent = self._used_percent(memory_available, memory_total)
        disk_used_percent = self._used_percent(disk_available, disk_total)

        uname = self._parse_uname(uname_query)

        status = "passed" if targets_total > 0 and targets_down == 0 else "warning"

        return PrometheusMetricsDTO(
            available=True,
            status=status,
            snapshot_time_utc=manifest.get("export_time_utc", "unknown"),
            prometheus_url=manifest.get("prometheus_url", "unknown"),
            targets_total=targets_total,
            targets_up=targets_up,
            targets_down=targets_down,
            memory_available_gb=round(memory_available / BYTES_IN_GB, 2) if memory_available else 0,
            memory_total_gb=round(memory_total / BYTES_IN_GB, 2) if memory_total else 0,
            memory_used_percent=memory_used_percent,
            disk_available_gb=round(disk_available / BYTES_IN_GB, 2) if disk_available else 0,
            disk_total_gb=round(disk_total / BYTES_IN_GB, 2) if disk_total else 0,
            disk_used_percent=disk_used_percent,
            system_name=uname.get("system_name", "unknown"),
            kernel_release=uname.get("kernel_release", "unknown"),
            source_dir=str(self.repository.metrics_dir),
            targets=targets,
        )

    def _unavailable(self) -> PrometheusMetricsDTO:
        return PrometheusMetricsDTO(
            available=False,
            status="missing",
            snapshot_time_utc="N/A",
            prometheus_url="N/A",
            targets_total=0,
            targets_up=0,
            targets_down=0,
            memory_available_gb=0,
            memory_total_gb=0,
            memory_used_percent=0,
            disk_available_gb=0,
            disk_total_gb=0,
            disk_used_percent=0,
            system_name="unknown",
            kernel_release="unknown",
            source_dir=str(self.repository.metrics_dir),
            targets=[],
        )

    def _parse_targets(self, query_data):
        targets = []

        for item in self._result_items(query_data):
            metric = item.get("metric", {})
            value = self._item_value(item)

            targets.append(
                PrometheusTargetDTO(
                    job=metric.get("job", "unknown"),
                    instance=metric.get("instance", "unknown"),
                    status="up" if value == 1 else "down",
                )
            )

        return targets

    def _parse_uname(self, query_data):
        items = self._result_items(query_data)

        if not items:
            return {"system_name": "unknown", "kernel_release": "unknown"}

        metric = items[0].get("metric", {})

        return {
            "system_name": metric.get("nodename", metric.get("sysname", "unknown")),
            "kernel_release": metric.get("release", "unknown"),
        }

    def _first_value(self, query_data):
        items = self._result_items(query_data)

        if not items:
            return 0.0

        return self._item_value(items[0])

    def _result_items(self, query_data):
        if not query_data:
            return []

        return query_data.get("data", {}).get("result", [])

    def _item_value(self, item):
        try:
            return float(item.get("value", [0, "0"])[1])
        except (ValueError, TypeError, IndexError):
            return 0.0

    def _used_percent(self, available, total):
        if not total:
            return 0.0

        used = max(total - available, 0)
        return round((used / total) * 100, 2)
