from dataclasses import dataclass


@dataclass
class InfrastructureNode:
    name: str
    node_type: str
    oob_ip: str
    oob_interface: str
    report_file: str
