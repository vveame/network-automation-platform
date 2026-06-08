from dto.prometheus_metrics_dto import (
    PrometheusMetricsDTO,
    PrometheusTargetDTO,
    PrometheusNodeMetricDTO,
    BlackboxProbeDTO,
    SNMPInterfaceDTO,
)


BYTES_IN_GB = 1024 ** 3

ERROR_RATE_THRESHOLD = 0.01
DISCARD_RATE_THRESHOLD = 0.01

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

        if not manifest or not up_query:
            return self._unavailable()

        targets = self._parse_targets(up_query)

        targets_total = len(targets)
        targets_up = len([target for target in targets if target.status == "up"])
        targets_down = max(targets_total - targets_up, 0)

        node_metrics = self._build_node_metrics(
            uname_query=self.repository.load_query("node_uname_info"),
            cpu_query=self.repository.load_query("node_cpu_usage_percent"),
            load1_query=self.repository.load_query("node_load1"),
            load5_query=self.repository.load_query("node_load5"),
            load15_query=self.repository.load_query("node_load15"),
            memory_available_query=self.repository.load_query("node_memory_available_bytes"),
            memory_total_query=self.repository.load_query("node_memory_total_bytes"),
            disk_available_query=self.repository.load_query("node_filesystem_available_bytes"),
            disk_total_query=self.repository.load_query("node_filesystem_size_bytes"),
            filesystem_readonly_query=self.repository.load_query("node_filesystem_readonly"),
        )

        blackbox_probes = self._parse_blackbox_probes(
            success_query=self.repository.load_query("blackbox_probe_success"),
            duration_query=self.repository.load_query("blackbox_probe_duration_seconds"),
            http_status_query=self.repository.load_query("blackbox_http_status_code"),
            dns_lookup_query=self.repository.load_query("blackbox_dns_lookup_time_seconds"),
        )

        snmp_targets = self._parse_targets(self.repository.load_query("snmp_up"))
        snmp_targets_total = len(snmp_targets)
        snmp_targets_up = len([target for target in snmp_targets if target.status == "up"])
        snmp_targets_down = max(snmp_targets_total - snmp_targets_up, 0)

        snmp_interfaces = self._parse_snmp_interfaces(
            admin_query=self.repository.load_query("snmp_if_admin_status"),
            oper_query=self.repository.load_query("snmp_if_oper_status"),
            in_octets_query=self.repository.load_query("snmp_if_hc_in_octets"),
            out_octets_query=self.repository.load_query("snmp_if_hc_out_octets"),
            in_octets_rate_query=self.repository.load_query("snmp_if_hc_in_octets_rate_5m"),
            out_octets_rate_query=self.repository.load_query("snmp_if_hc_out_octets_rate_5m"),
            in_errors_query=self.repository.load_query("snmp_if_in_errors"),
            out_errors_query=self.repository.load_query("snmp_if_out_errors"),
            in_errors_rate_query=self.repository.load_query("snmp_if_in_errors_rate_5m"),
            out_errors_rate_query=self.repository.load_query("snmp_if_out_errors_rate_5m"),
            in_discards_query=self.repository.load_query("snmp_if_in_discards"),
            out_discards_query=self.repository.load_query("snmp_if_out_discards"),
            in_discards_rate_query=self.repository.load_query("snmp_if_in_discards_rate_5m"),
            out_discards_rate_query=self.repository.load_query("snmp_if_out_discards_rate_5m"),
            if_speed_query=self.repository.load_query("snmp_if_speed"),
            if_high_speed_query=self.repository.load_query("snmp_if_high_speed"),
            if_mtu_query=self.repository.load_query("snmp_if_mtu"),
        )

        snmp_health_interfaces = [
            iface for iface in snmp_interfaces if iface.health_relevant
        ]

        snmp_interfaces_total = len(snmp_health_interfaces)
        snmp_interfaces_up = len(
            [iface for iface in snmp_health_interfaces if iface.oper_status == "up"]
        )
        snmp_interfaces_down = len(
            [iface for iface in snmp_health_interfaces if iface.oper_status != "up"]
        )

        snmp_unexpected_down = [
            iface for iface in snmp_health_interfaces
            if iface.admin_status == "up" and iface.oper_status != "up"
        ]

        snmp_with_errors = [
            iface for iface in snmp_health_interfaces
            if iface.total_errors > 0
        ]

        snmp_with_error_rate = [
            iface for iface in snmp_health_interfaces
            if iface.total_error_rate >= ERROR_RATE_THRESHOLD
        ]

        snmp_with_discards = [
            iface for iface in snmp_health_interfaces
            if iface.total_discards > 0
        ]

        snmp_with_discard_rate = [
            iface for iface in snmp_health_interfaces
            if iface.total_discard_rate >= DISCARD_RATE_THRESHOLD
        ]

        memory_available = sum(node.memory_available_gb for node in node_metrics)
        memory_total = sum(node.memory_total_gb for node in node_metrics)
        disk_available = sum(node.disk_available_gb for node in node_metrics)
        disk_total = sum(node.disk_total_gb for node in node_metrics)

        memory_used_percent = self._used_percent(memory_available, memory_total)
        disk_used_percent = self._used_percent(disk_available, disk_total)

        max_cpu_usage_percent = max(
            [node.cpu_usage_percent for node in node_metrics],
            default=0.0,
        )
        max_load1 = max(
            [node.load1 for node in node_metrics],
            default=0.0,
        )
        filesystem_readonly_count = len(
            [node for node in node_metrics if node.filesystem_readonly]
        )

        blackbox_total = len(blackbox_probes)
        blackbox_success = len(
            [probe for probe in blackbox_probes if probe.status == "success"]
        )
        blackbox_failed = max(blackbox_total - blackbox_success, 0)
        blackbox_max_duration = max(
            [probe.duration_seconds for probe in blackbox_probes],
            default=0.0,
        )

        status = "passed"

        if (
            targets_total == 0
            or targets_down > 0
            or blackbox_failed > 0
            or snmp_targets_down > 0
            or snmp_interfaces_down > 0
            or filesystem_readonly_count > 0
            or max_cpu_usage_percent >= 85
            or memory_used_percent >= 85
            or disk_used_percent >= 85
            or len(snmp_with_error_rate) > 0
            or len(snmp_with_discard_rate) > 0
        ):
            status = "warning"

        first_node = node_metrics[0] if node_metrics else None

        return PrometheusMetricsDTO(
            available=True,
            status=status,
            snapshot_time_utc=manifest.get("export_time_utc", "unknown"),
            prometheus_url=manifest.get("prometheus_url", "unknown"),
            source_dir=str(self.repository.metrics_dir),

            targets_total=targets_total,
            targets_up=targets_up,
            targets_down=targets_down,

            memory_available_gb=round(memory_available, 2),
            memory_total_gb=round(memory_total, 2),
            memory_used_percent=memory_used_percent,

            disk_available_gb=round(disk_available, 2),
            disk_total_gb=round(disk_total, 2),
            disk_used_percent=disk_used_percent,

            max_cpu_usage_percent=round(max_cpu_usage_percent, 2),
            max_load1=round(max_load1, 2),
            filesystem_readonly_count=filesystem_readonly_count,

            system_name=first_node.system_name if first_node else "multiple-nodes",
            kernel_release=first_node.kernel_release if first_node else "unknown",

            targets=targets,
            node_metrics=node_metrics,
            blackbox_probes=blackbox_probes,

            blackbox_probes_total=blackbox_total,
            blackbox_probes_success=blackbox_success,
            blackbox_probes_failed=blackbox_failed,
            blackbox_max_duration_seconds=round(blackbox_max_duration, 4),

            snmp_available=snmp_targets_total > 0 or len(snmp_interfaces) > 0,
            snmp_targets_total=snmp_targets_total,
            snmp_targets_up=snmp_targets_up,
            snmp_targets_down=snmp_targets_down,

            snmp_interfaces_total=snmp_interfaces_total,
            snmp_interfaces_up=snmp_interfaces_up,
            snmp_interfaces_down=snmp_interfaces_down,
            snmp_interfaces_unexpected_down_count=len(snmp_unexpected_down),

            snmp_interfaces_with_errors_count=len(snmp_with_errors),
            snmp_interfaces_with_error_rate_count=len(snmp_with_error_rate),
            snmp_interfaces_with_discards_count=len(snmp_with_discards),
            snmp_interfaces_with_discard_rate_count=len(snmp_with_discard_rate),

            snmp_interfaces=snmp_interfaces,
        )

    def _unavailable(self) -> PrometheusMetricsDTO:
        return PrometheusMetricsDTO(
            available=False,
            status="missing",
            snapshot_time_utc="N/A",
            prometheus_url="N/A",
            source_dir=str(self.repository.metrics_dir),

            targets_total=0,
            targets_up=0,
            targets_down=0,

            memory_available_gb=0,
            memory_total_gb=0,
            memory_used_percent=0,

            disk_available_gb=0,
            disk_total_gb=0,
            disk_used_percent=0,

            max_cpu_usage_percent=0,
            max_load1=0,
            filesystem_readonly_count=0,

            system_name="unknown",
            kernel_release="unknown",

            targets=[],
            node_metrics=[],
            blackbox_probes=[],

            blackbox_probes_total=0,
            blackbox_probes_success=0,
            blackbox_probes_failed=0,
            blackbox_max_duration_seconds=0,

            snmp_available=False,
            snmp_targets_total=0,
            snmp_targets_up=0,
            snmp_targets_down=0,

            snmp_interfaces_total=0,
            snmp_interfaces_up=0,
            snmp_interfaces_down=0,
            snmp_interfaces_unexpected_down_count=0,

            snmp_interfaces_with_errors_count=0,
            snmp_interfaces_with_error_rate_count=0,
            snmp_interfaces_with_discards_count=0,
            snmp_interfaces_with_discard_rate_count=0,

            snmp_interfaces=[],
        )

    def _build_node_metrics(
        self,
        uname_query,
        cpu_query,
        load1_query,
        load5_query,
        load15_query,
        memory_available_query,
        memory_total_query,
        disk_available_query,
        disk_total_query,
        filesystem_readonly_query,
    ):
        uname_by_instance = self._items_by_instance(uname_query)

        cpu_by_instance = self._values_by_instance(cpu_query)
        load1_by_instance = self._values_by_instance(load1_query)
        load5_by_instance = self._values_by_instance(load5_query)
        load15_by_instance = self._values_by_instance(load15_query)

        memory_available_by_instance = self._values_by_instance(memory_available_query)
        memory_total_by_instance = self._values_by_instance(memory_total_query)

        disk_available_by_instance = self._values_by_instance(disk_available_query)
        disk_total_by_instance = self._values_by_instance(disk_total_query)

        readonly_by_instance = self._values_by_instance(filesystem_readonly_query)

        instances = sorted(
            set(uname_by_instance.keys())
            | set(memory_total_by_instance.keys())
            | set(cpu_by_instance.keys())
            | set(load1_by_instance.keys())
        )

        nodes = []

        for instance in instances:
            memory_available_bytes = memory_available_by_instance.get(instance, 0)
            memory_total_bytes = memory_total_by_instance.get(instance, 0)

            disk_available_bytes = disk_available_by_instance.get(instance, 0)
            disk_total_bytes = disk_total_by_instance.get(instance, 0)

            uname_metric = uname_by_instance.get(instance, {}).get("metric", {})

            memory_available_gb = (
                memory_available_bytes / BYTES_IN_GB if memory_available_bytes else 0
            )
            memory_total_gb = (
                memory_total_bytes / BYTES_IN_GB if memory_total_bytes else 0
            )

            disk_available_gb = (
                disk_available_bytes / BYTES_IN_GB if disk_available_bytes else 0
            )
            disk_total_gb = (
                disk_total_bytes / BYTES_IN_GB if disk_total_bytes else 0
            )

            nodes.append(
                PrometheusNodeMetricDTO(
                    instance=instance,
                    node_name=uname_metric.get(
                        "node_name",
                        uname_metric.get("nodename", instance),
                    ),
                    role=uname_metric.get("role", self._guess_role(instance)),
                    system_name=uname_metric.get("sysname", "unknown"),
                    kernel_release=uname_metric.get("release", "unknown"),

                    cpu_usage_percent=round(cpu_by_instance.get(instance, 0.0), 2),
                    load1=round(load1_by_instance.get(instance, 0.0), 2),
                    load5=round(load5_by_instance.get(instance, 0.0), 2),
                    load15=round(load15_by_instance.get(instance, 0.0), 2),

                    memory_available_gb=round(memory_available_gb, 2),
                    memory_total_gb=round(memory_total_gb, 2),
                    memory_used_percent=self._used_percent(
                        memory_available_gb,
                        memory_total_gb,
                    ),

                    disk_available_gb=round(disk_available_gb, 2),
                    disk_total_gb=round(disk_total_gb, 2),
                    disk_used_percent=self._used_percent(
                        disk_available_gb,
                        disk_total_gb,
                    ),

                    filesystem_readonly=readonly_by_instance.get(instance, 0) == 1,
                )
            )

        return nodes

    def _parse_blackbox_probes(
        self,
        success_query,
        duration_query,
        http_status_query,
        dns_lookup_query,
    ):
        duration_by_key = self._values_by_blackbox_key(duration_query)
        http_status_by_key = self._values_by_blackbox_key(http_status_query)
        dns_lookup_by_key = self._values_by_blackbox_key(dns_lookup_query)

        probes = []

        for item in self._result_items(success_query):
            metric = item.get("metric", {})
            value = self._item_value(item)
            key = self._blackbox_key(metric)

            probes.append(
                BlackboxProbeDTO(
                    service_name=metric.get("service_name", metric.get("instance", "unknown")),
                    job=metric.get("job", "unknown"),
                    instance=metric.get("instance", "unknown"),
                    role=metric.get("role", "unknown"),
                    probe_type=metric.get("probe_type", "unknown"),
                    status="success" if value == 1 else "failed",
                    duration_seconds=round(duration_by_key.get(key, 0.0), 4),
                    http_status_code=int(http_status_by_key.get(key, 0)),
                    dns_lookup_time_seconds=round(dns_lookup_by_key.get(key, 0.0), 4),
                )
            )

        return sorted(probes, key=lambda probe: probe.service_name)

    def _parse_snmp_interfaces(
        self,
        admin_query,
        oper_query,
        in_octets_query,
        out_octets_query,
        in_octets_rate_query,
        out_octets_rate_query,
        in_errors_query,
        out_errors_query,
        in_errors_rate_query,
        out_errors_rate_query,
        in_discards_query,
        out_discards_query,
        in_discards_rate_query,
        out_discards_rate_query,
        if_speed_query,
        if_high_speed_query,
        if_mtu_query,
    ):
        admin_by_key = self._values_by_snmp_interface_key(admin_query)

        in_octets_by_key = self._values_by_snmp_interface_key(in_octets_query)
        out_octets_by_key = self._values_by_snmp_interface_key(out_octets_query)

        in_octets_rate_by_key = self._values_by_snmp_interface_key(in_octets_rate_query)
        out_octets_rate_by_key = self._values_by_snmp_interface_key(out_octets_rate_query)

        in_errors_by_key = self._values_by_snmp_interface_key(in_errors_query)
        out_errors_by_key = self._values_by_snmp_interface_key(out_errors_query)
        in_errors_rate_by_key = self._values_by_snmp_interface_key(in_errors_rate_query)
        out_errors_rate_by_key = self._values_by_snmp_interface_key(out_errors_rate_query)

        in_discards_by_key = self._values_by_snmp_interface_key(in_discards_query)
        out_discards_by_key = self._values_by_snmp_interface_key(out_discards_query)
        in_discards_rate_by_key = self._values_by_snmp_interface_key(in_discards_rate_query)
        out_discards_rate_by_key = self._values_by_snmp_interface_key(out_discards_rate_query)

        if_speed_by_key = self._values_by_snmp_interface_key(if_speed_query)
        if_high_speed_by_key = self._values_by_snmp_interface_key(if_high_speed_query)
        if_mtu_by_key = self._values_by_snmp_interface_key(if_mtu_query)

        interfaces = []

        for item in self._result_items(oper_query):
            metric = item.get("metric", {})
            key = self._snmp_interface_key(metric)

            if_name = metric.get("ifName", metric.get("ifDescr", "unknown"))

            admin_value = int(admin_by_key.get(key, 0))
            oper_value = int(self._item_value(item))

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
                SNMPInterfaceDTO(
                    node_name=metric.get("node_name", metric.get("instance", "unknown")),
                    instance=metric.get("instance", "unknown"),
                    role=metric.get("role", "unknown"),
                    device_type=metric.get("device_type", "unknown"),

                    if_name=if_name,
                    if_descr=metric.get("ifDescr", "unknown"),
                    if_index=metric.get("ifIndex", "unknown"),

                    admin_status=SNMP_STATUS_MAP.get(admin_value, f"unknown_{admin_value}"),
                    oper_status=SNMP_STATUS_MAP.get(oper_value, f"unknown_{oper_value}"),
                    health_relevant=self._is_health_relevant_snmp_interface(if_name),

                    in_octets=int(in_octets_by_key.get(key, 0)),
                    out_octets=int(out_octets_by_key.get(key, 0)),
                    in_bps=round(in_bps, 2),
                    out_bps=round(out_bps, 2),

                    in_errors=in_errors,
                    out_errors=out_errors,
                    total_errors=in_errors + out_errors,
                    in_error_rate=round(in_error_rate, 4),
                    out_error_rate=round(out_error_rate, 4),
                    total_error_rate=round(in_error_rate + out_error_rate, 4),

                    in_discards=in_discards,
                    out_discards=out_discards,
                    total_discards=in_discards + out_discards,
                    in_discard_rate=round(in_discard_rate, 4),
                    out_discard_rate=round(out_discard_rate, 4),
                    total_discard_rate=round(in_discard_rate + out_discard_rate, 4),

                    if_speed_bps=int(if_speed_by_key.get(key, 0)),
                    if_high_speed_mbps=int(if_high_speed_by_key.get(key, 0)),
                    if_mtu=int(if_mtu_by_key.get(key, 0)),
                )
            )

        return sorted(interfaces, key=lambda iface: (iface.node_name, iface.if_name))

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
                    node_name=metric.get("node_name", "unknown"),
                    role=metric.get("role", "unknown"),
                    device_type=metric.get("device_type", "unknown"),
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

    def _guess_role(self, instance):
        if "192.168.248.131" in instance:
            return "gns3-host"

        if "localhost" in instance or "127.0.0.1" in instance:
            return "devops"

        return "node-exporter"
