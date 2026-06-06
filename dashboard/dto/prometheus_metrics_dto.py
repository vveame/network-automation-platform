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
