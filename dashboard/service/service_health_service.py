from typing import Dict, Any, List

from dto.service_dto import ServiceDTO


class ServiceHealthService:
    def build_services(self, vars_data: Dict[str, Any], report_status_map: Dict[str, str]) -> List[ServiceDTO]:
        expected_services = vars_data.get("expected_services", {})

        if expected_services:
            return self._build_from_expected_services(expected_services, report_status_map)

        return self._build_from_dmz_vars(vars_data, report_status_map)

    def _build_from_expected_services(self, expected_services: Dict[str, Any], report_status_map: Dict[str, str]) -> List[ServiceDTO]:
        services = []

        for service_name, data in expected_services.items():
            services.append(
                ServiceDTO(
                    name=self._display_name(service_name),
                    ip=str(data.get("ip", "N/A")),
                    port=str(data.get("port", "N/A")),
                    status=self._service_status(service_name, report_status_map),
                    validation_method=self._validation_method(service_name, data),
                )
            )

        return services

    def _build_from_dmz_vars(self, vars_data: Dict[str, Any], report_status_map: Dict[str, str]) -> List[ServiceDTO]:
        dmz = vars_data.get("dmz", {})
        dmz_status = report_status_map.get("dmz-services.txt", "missing")

        services = []

        if dmz.get("web_ip"):
            services.append(
                ServiceDTO(
                    name="DMZ Web Server",
                    ip=dmz.get("web_ip"),
                    port="80",
                    status=dmz_status,
                    validation_method="HTTP health check",
                )
            )

        if dmz.get("dns_ip"):
            services.append(
                ServiceDTO(
                    name="DMZ DNS Server",
                    ip=dmz.get("dns_ip"),
                    port="53",
                    status=dmz_status,
                    validation_method="DNS query check",
                )
            )

        return services

    def _service_status(self, service_name: str, report_status_map: Dict[str, str]) -> str:
        for filename, status in report_status_map.items():
            if service_name.lower() in filename.lower():
                return status

        if "dmz-services.txt" in report_status_map:
            return report_status_map["dmz-services.txt"]

        return "missing"

    def _validation_method(self, service_name: str, data: Dict[str, Any]) -> str:
        if data.get("url"):
            return "HTTP health check"

        if data.get("test_domain"):
            return "DNS query check"

        if data.get("port"):
            return f"TCP/{data.get('port')} check"

        return f"{service_name} validation"

    def _display_name(self, service_name: str) -> str:
        return service_name.replace("_", " ").replace("-", " ").title()
