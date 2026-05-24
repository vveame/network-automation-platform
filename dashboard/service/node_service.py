from typing import Dict, Any, List

from entity.infrastructure_node import InfrastructureNode
from dto.node_dto import NodeDTO
from mapper.node_mapper import NodeMapper


class NodeService:
    def __init__(self):
        self.node_mapper = NodeMapper()

    def build_nodes(self, vars_data: Dict[str, Any], report_status_map: Dict[str, str]) -> List[NodeDTO]:
        nodes = []

        expected_frr = vars_data.get("expected_frr_nodes", {})
        expected_ovs = vars_data.get("expected_ovs_nodes", {})

        for name, data in expected_frr.items():
            report_file = self._find_report_file(
                node_name=name,
                expected_suffix="-frr.txt",
                report_status_map=report_status_map,
            )

            node = InfrastructureNode(
                name=name,
                node_type="FRR Router",
                oob_ip=data.get("oob_ip", "N/A"),
                oob_interface=data.get("oob_interface", "N/A"),
                report_file=report_file,
            )

            nodes.append(
                self.node_mapper.to_dto(
                    node=node,
                    validation_status=report_status_map.get(report_file, "missing"),
                )
            )

        for name, data in expected_ovs.items():
            report_file = self._find_report_file(
                node_name=name,
                expected_suffix="-ovs.txt",
                report_status_map=report_status_map,
            )

            node = InfrastructureNode(
                name=name,
                node_type="OVS Switch",
                oob_ip=data.get("oob_ip", "N/A"),
                oob_interface=data.get("oob_interface", "N/A"),
                report_file=report_file,
            )

            nodes.append(
                self.node_mapper.to_dto(
                    node=node,
                    validation_status=report_status_map.get(report_file, "missing"),
                )
            )

        return sorted(nodes, key=lambda item: (item.node_type, item.name))

    def _find_report_file(self, node_name: str, expected_suffix: str, report_status_map: Dict[str, str]) -> str:
        expected_name = f"{node_name}{expected_suffix}"

        if expected_name in report_status_map:
            return expected_name

        for filename in report_status_map.keys():
            if node_name in filename:
                return filename

        return expected_name
