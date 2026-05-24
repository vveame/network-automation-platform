from dataclasses import dataclass


@dataclass
class NodeDTO:
    name: str
    node_type: str
    oob_ip: str
    oob_interface: str
    validation_status: str
    report_file: str
