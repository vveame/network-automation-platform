from dataclasses import dataclass
from typing import List


@dataclass
class PrometheusTargetDTO:
    job: str
    instance: str
    status: str


@dataclass
class PrometheusNodeMetricDTO:
    instance: str
    node_name: str
    role: str
    system_name: str
    kernel_release: str
    memory_available_gb: float
    memory_total_gb: float
    memory_used_percent: float
    disk_available_gb: float
    disk_total_gb: float
    disk_used_percent: float


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


@dataclass
class SNMPInterfaceDTO:
    node_name: str
    instance: str
    if_name: str
    if_descr: str
    if_index: str
    admin_status: str
    oper_status: str
    in_octets: int
    out_octets: int
    in_errors: int
    out_errors: int


@dataclass
class PrometheusMetricsDTO:
    available: bool
    status: str
    snapshot_time_utc: str
    prometheus_url: str

    targets_total: int
    targets_up: int
    targets_down: int

    memory_available_gb: float
    memory_total_gb: float
    memory_used_percent: float

    disk_available_gb: float
    disk_total_gb: float
    disk_used_percent: float

    system_name: str
    kernel_release: str
    source_dir: str

    targets: List[PrometheusTargetDTO]
    node_metrics: List[PrometheusNodeMetricDTO]
    blackbox_probes: List[BlackboxProbeDTO]

    snmp_available: bool
    snmp_targets_total: int
    snmp_targets_up: int
    snmp_targets_down: int
    snmp_interfaces_total: int
    snmp_interfaces_up: int
    snmp_interfaces_down: int
    snmp_interfaces: List[SNMPInterfaceDTO]
