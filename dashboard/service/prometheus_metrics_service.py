from dto.prometheus_metrics_dto import (
    PrometheusMetricsDTO,
    PrometheusTargetDTO,
    PrometheusNodeMetricDTO,
    BlackboxProbeDTO,
    SNMPInterfaceDTO,
)


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

        blackbox_success_query = self.repository.load_query("blackbox_probe_success")
        blackbox_duration_query = self.repository.load_query("blackbox_probe_duration_seconds")
        blackbox_http_status_query = self.repository.load_query("blackbox_http_status_code")

        snmp_up_query = self.repository.load_query("snmp_up")
        snmp_admin_query = self.repository.load_query("snmp_if_admin_status")
        snmp_oper_query = self.repository.load_query("snmp_if_oper_status")
        snmp_in_octets_query = self.repository.load_query("snmp_if_hc_in_octets")
        snmp_out_octets_query = self.repository.load_query("snmp_if_hc_out_octets")
        snmp_in_errors_query = self.repository.load_query("snmp_if_in_errors")
        snmp_out_errors_query = self.repository.load_query("snmp_if_out_errors")

        if not manifest or not up_query:
            return self._unavailable()

        targets = self._parse_targets(up_query)
        targets_total = len(targets)
        targets_up = len([target for target in targets if target.status == "up"])
        targets_down = max(targets_total - targets_up, 0)

        node_metrics = self._build_node_metrics(
            uname_query=uname_query,
            memory_available_query=memory_available_query,
            memory_total_query=memory_total_query,
            disk_available_query=disk_available_query,
            disk_total_query=disk_total_query,
        )

        blackbox_probes = self._parse_blackbox_probes(
            success_query=blackbox_success_query,
            duration_query=blackbox_duration_query,
            http_status_query=blackbox_http_status_query,
        )

        snmp_targets = self._parse_targets(snmp_up_query)
        snmp_targets_total = len(snmp_targets)
        snmp_targets_up = len([target for target in snmp_targets if target.status == "up"])
        snmp_targets_down = max(snmp_targets_total - snmp_targets_up, 0)

        snmp_interfaces = self._parse_snmp_interfaces(
            admin_query=snmp_admin_query,
            oper_query=snmp_oper_query,
            in_octets_query=snmp_in_octets_query,
            out_octets_query=snmp_out_octets_query,
            in_errors_query=snmp_in_errors_query,
            out_errors_query=snmp_out_errors_query,
        )

        snmp_health_interfaces = [
            iface for iface in snmp_interfaces
            if self._is_health_relevant_snmp_interface(iface.if_name)
        ]

        snmp_interfaces_total = len(snmp_health_interfaces)
        snmp_interfaces_up = len(
            [iface for iface in snmp_health_interfaces if iface.oper_status == "up"]
        )
        snmp_interfaces_down = len(
            [iface for iface in snmp_health_interfaces if iface.oper_status != "up"]
        )

        memory_available = sum(node.memory_available_gb for node in node_metrics)
        memory_total = sum(node.memory_total_gb for node in node_metrics)
        disk_available = sum(node.disk_available_gb for node in node_metrics)
        disk_total = sum(node.disk_total_gb for node in node_metrics)

        memory_used_percent = self._used_percent(memory_available, memory_total)
        disk_used_percent = self._used_percent(disk_available, disk_total)

        failed_probes = len([probe for probe in blackbox_probes if probe.status != "success"])

        status = "passed"
        if targets_total == 0 or targets_down > 0 or failed_probes > 0 or snmp_targets_down > 0 or snmp_interfaces_down > 0:
            status = "warning"

        first_node = node_metrics[0] if node_metrics else None

        return PrometheusMetricsDTO(
            available=True,
            status=status,
            snapshot_time_utc=manifest.get("export_time_utc", "unknown"),
            prometheus_url=manifest.get("prometheus_url", "unknown"),
            targets_total=targets_total,
            targets_up=targets_up,
            targets_down=targets_down,
            memory_available_gb=round(memory_available, 2),
            memory_total_gb=round(memory_total, 2),
            memory_used_percent=memory_used_percent,
            disk_available_gb=round(disk_available, 2),
            disk_total_gb=round(disk_total, 2),
            disk_used_percent=disk_used_percent,
            system_name=first_node.system_name if first_node else "multiple-nodes",
            kernel_release=first_node.kernel_release if first_node else "unknown",
            source_dir=str(self.repository.metrics_dir),
            targets=targets,
            node_metrics=node_metrics,
            blackbox_probes=blackbox_probes,
            snmp_available=snmp_targets_total > 0 or snmp_interfaces_total > 0,
            snmp_targets_total=snmp_targets_total,
            snmp_targets_up=snmp_targets_up,
            snmp_targets_down=snmp_targets_down,
            snmp_interfaces_total=snmp_interfaces_total,
            snmp_interfaces_up=snmp_interfaces_up,
            snmp_interfaces_down=snmp_interfaces_down,
            snmp_interfaces=snmp_interfaces,
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
            node_metrics=[],
            blackbox_probes=[],
            snmp_available=False,
            snmp_targets_total=0,
            snmp_targets_up=0,
            snmp_targets_down=0,
            snmp_interfaces_total=0,
            snmp_interfaces_up=0,
            snmp_interfaces_down=0,
            snmp_interfaces=[],
        )

    def _parse_snmp_interfaces(
        self,
        admin_query,
        oper_query,
        in_octets_query,
        out_octets_query,
        in_errors_query,
        out_errors_query,
    ):
        admin_by_key = self._values_by_snmp_interface_key(admin_query)
        in_octets_by_key = self._values_by_snmp_interface_key(in_octets_query)
        out_octets_by_key = self._values_by_snmp_interface_key(out_octets_query)
        in_errors_by_key = self._values_by_snmp_interface_key(in_errors_query)
        out_errors_by_key = self._values_by_snmp_interface_key(out_errors_query)

        interfaces = []

        for item in self._result_items(oper_query):
            metric = item.get("metric", {})
            key = self._snmp_interface_key(metric)

            admin_value = int(admin_by_key.get(key, 0))
            oper_value = int(self._item_value(item))

            interfaces.append(
                SNMPInterfaceDTO(
                    node_name=metric.get("node_name", metric.get("instance", "unknown")),
                    instance=metric.get("instance", "unknown"),
                    if_name=metric.get("ifName", metric.get("ifDescr", "unknown")),
                    if_descr=metric.get("ifDescr", "unknown"),
                    if_index=metric.get("ifIndex", "unknown"),
                    admin_status=SNMP_STATUS_MAP.get(admin_value, f"unknown_{admin_value}"),
                    oper_status=SNMP_STATUS_MAP.get(oper_value, f"unknown_{oper_value}"),
                    in_octets=int(in_octets_by_key.get(key, 0)),
                    out_octets=int(out_octets_by_key.get(key, 0)),
                    in_errors=int(in_errors_by_key.get(key, 0)),
                    out_errors=int(out_errors_by_key.get(key, 0)),
                )
            )

        return sorted(interfaces, key=lambda iface: (iface.node_name, iface.if_name))

    def _parse_blackbox_probes(self, success_query, duration_query, http_status_query):
        duration_by_key = self._values_by_blackbox_key(duration_query)
        http_status_by_key = self._values_by_blackbox_key(http_status_query)

        probes = []

        for item in self._result_items(success_query):
            metric = item.get("metric", {})
            value = self._item_value(item)

            key = self._blackbox_key(metric)
            duration = duration_by_key.get(key, 0.0)
            http_status_code = int(http_status_by_key.get(key, 0))

            service_name = metric.get("service_name", metric.get("instance", "unknown"))

            probes.append(
                BlackboxProbeDTO(
                    service_name=service_name,
                    job=metric.get("job", "unknown"),
                    instance=metric.get("instance", "unknown"),
                    role=metric.get("role", "unknown"),
                    probe_type=metric.get("probe_type", "unknown"),
                    status="success" if value == 1 else "failed",
                    duration_seconds=round(duration, 4),
                    http_status_code=http_status_code,
                )
            )

        return sorted(probes, key=lambda probe: probe.service_name)

    def _build_node_metrics(
        self,
        uname_query,
        memory_available_query,
        memory_total_query,
        disk_available_query,
        disk_total_query,
    ):
        uname_by_instance = self._items_by_instance(uname_query)
        memory_available_by_instance = self._values_by_instance(memory_available_query)
        memory_total_by_instance = self._values_by_instance(memory_total_query)
        disk_available_by_instance = self._values_by_instance(disk_available_query)
        disk_total_by_instance = self._values_by_instance(disk_total_query)

        instances = sorted(memory_total_by_instance.keys())
        nodes = []

        for instance in instances:
            memory_available_bytes = memory_available_by_instance.get(instance, 0)
            memory_total_bytes = memory_total_by_instance.get(instance, 0)
            disk_available_bytes = disk_available_by_instance.get(instance, 0)
            disk_total_bytes = disk_total_by_instance.get(instance, 0)

            uname_metric = uname_by_instance.get(instance, {}).get("metric", {})

            memory_available_gb = memory_available_bytes / BYTES_IN_GB if memory_available_bytes else 0
            memory_total_gb = memory_total_bytes / BYTES_IN_GB if memory_total_bytes else 0
            disk_available_gb = disk_available_bytes / BYTES_IN_GB if disk_available_bytes else 0
            disk_total_gb = disk_total_bytes / BYTES_IN_GB if disk_total_bytes else 0

            nodes.append(
                PrometheusNodeMetricDTO(
                    instance=instance,
                    node_name=uname_metric.get("node_name", uname_metric.get("nodename", instance)),
                    role=uname_metric.get("role", self._guess_role(instance)),
                    system_name=uname_metric.get("sysname", "unknown"),
                    kernel_release=uname_metric.get("release", "unknown"),
                    memory_available_gb=round(memory_available_gb, 2),
                    memory_total_gb=round(memory_total_gb, 2),
                    memory_used_percent=self._used_percent(memory_available_gb, memory_total_gb),
                    disk_available_gb=round(disk_available_gb, 2),
                    disk_total_gb=round(disk_total_gb, 2),
                    disk_used_percent=self._used_percent(disk_available_gb, disk_total_gb),
                )
            )

        return nodes

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

    def _items_by_instance(self, query_data):
        result = {}

        for item in self._result_items(query_data):
            instance = item.get("metric", {}).get("instance", "unknown")
            result[instance] = item

        return result

    def _values_by_instance(self, query_data):
        result = {}

        for item in self._result_items(query_data):
            instance = item.get("metric", {}).get("instance", "unknown")
            result[instance] = self._item_value(item)

        return result

    def _values_by_blackbox_key(self, query_data):
        result = {}

        for item in self._result_items(query_data):
            metric = item.get("metric", {})
            result[self._blackbox_key(metric)] = self._item_value(item)

        return result

    def _values_by_snmp_interface_key(self, query_data):
        result = {}

        for item in self._result_items(query_data):
            metric = item.get("metric", {})
            result[self._snmp_interface_key(metric)] = self._item_value(item)

        return result

    def _blackbox_key(self, metric):
        return (
            metric.get("job", "unknown"),
            metric.get("instance", "unknown"),
            metric.get("service_name", "unknown"),
        )

    def _snmp_interface_key(self, metric):
        return (
            metric.get("instance", "unknown"),
            metric.get("ifIndex", "unknown"),
            metric.get("ifName", metric.get("ifDescr", "unknown")),
        )

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

    def _is_health_relevant_snmp_interface(self, if_name):
        if not if_name:
            return False

        ignored_exact = {"lo"}
        ignored_prefixes = ("vrrp",)

        if if_name in ignored_exact:
            return False

        if if_name.startswith(ignored_prefixes):
            return False

        return True

    def _guess_role(self, instance):
        if "192.168.248.131" in instance:
            return "gns3-host"
        if "localhost" in instance or "127.0.0.1" in instance:
            return "devops"
        return "node-exporter"
