from dataclasses import dataclass


@dataclass
class ServiceDTO:
    name: str
    ip: str
    port: str
    status: str
    validation_method: str
