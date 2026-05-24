from dataclasses import dataclass


@dataclass
class ValidationService:
    name: str
    ip: str
    port: str
    validation_method: str
