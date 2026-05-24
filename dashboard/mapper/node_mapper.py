from dto.node_dto import NodeDTO
from entity.infrastructure_node import InfrastructureNode


class NodeMapper:
    def to_dto(self, node: InfrastructureNode, validation_status: str) -> NodeDTO:
        return NodeDTO(
            name=node.name,
            node_type=node.node_type,
            oob_ip=node.oob_ip,
            oob_interface=node.oob_interface,
            validation_status=validation_status,
            report_file=node.report_file,
        )
