from dataclasses import dataclass
from typing import List


@dataclass
class PrometheusTargetDTO:
    job: str
    instance: str
    status: str
    node_name: str = "unknown"
    role: str = "unknown"
    device_type: str = "unknown"


@dataclass
class PrometheusNodeMetricDTO:
    instance: str
    node_name: str
    role: str
    system_name: str
    kernel_release: str

    cpu_usage_percent: float
    load1: float
    load5: float
    load15: float

    memory_available_gb: float
    memory_total_gb: float
    memory_used_percent: float

    disk_available_gb: float
    disk_total_gb: float
    disk_used_percent: float

    filesystem_readonly: bool


@dataclass
class BlackboxProbeDTO:
    service_name: str
    job: str
    instance: str
    role: str
    probe_type: str
    status: str
    duration_seconds: float
    http_status_code: int
    dns_lookup_time_seconds: float


@dataclass
class SNMPInterfaceDTO:
    node_name: str
    instance: str
    role: str
    device_type: str

    if_name: str
    if_descr: str
    if_index: str

    admin_status: str
    oper_status: str
    health_relevant: bool

    in_octets: int
    out_octets: int
    in_bps: float
    out_bps: float

    in_errors: int
    out_errors: int
    total_errors: int
    in_error_rate: float
    out_error_rate: float
    total_error_rate: float

    in_discards: int
    out_discards: int
    total_discards: int
    in_discard_rate: float
    out_discard_rate: float
    total_discard_rate: float

    if_speed_bps: int
    if_high_speed_mbps: int
    if_mtu: int


@dataclass
class PrometheusMetricsDTO:
    available: bool
    status: str

    snapshot_time_utc: str
    prometheus_url: str
    source_dir: str

    targets_total: int
    targets_up: int
    targets_down: int

    memory_available_gb: float
    memory_total_gb: float
    memory_used_percent: float

    disk_available_gb: float
    disk_total_gb: float
    disk_used_percent: float

    max_cpu_usage_percent: float
    max_load1: float
    filesystem_readonly_count: int

    system_name: str
    kernel_release: str

    targets: List[PrometheusTargetDTO]
    node_metrics: List[PrometheusNodeMetricDTO]
    blackbox_probes: List[BlackboxProbeDTO]

    blackbox_probes_total: int
    blackbox_probes_success: int
    blackbox_probes_failed: int
    blackbox_max_duration_seconds: float

    snmp_available: bool
    snmp_targets_total: int
    snmp_targets_up: int
    snmp_targets_down: int

    snmp_interfaces_total: int
    snmp_interfaces_up: int
    snmp_interfaces_down: int
    snmp_interfaces_unexpected_down_count: int

    snmp_interfaces_with_errors_count: int
    snmp_interfaces_with_error_rate_count: int
    snmp_interfaces_with_discards_count: int
    snmp_interfaces_with_discard_rate_count: int

    snmp_interfaces: List[SNMPInterfaceDTO]
