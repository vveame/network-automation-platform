from dataclasses import dataclass


@dataclass
class AnsibleReport:
    filename: str
    content: str
    size_kb: float
    updated_at: str
