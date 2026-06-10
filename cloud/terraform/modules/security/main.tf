resource "aws_security_group" "admin" {
  name        = "${var.name_prefix}-tunnel-gateway-sg"
  description = "Security group for public EC2 tunnel gateway"
  vpc_id      = var.vpc_id
  tags        = merge(var.common_tags, { Name = "${var.name_prefix}-tunnel-gateway-sg", Role = "hybrid-tunnel-gateway" })
}

resource "aws_vpc_security_group_ingress_rule" "admin_ssh" {
  security_group_id = aws_security_group.admin.id
  description       = "Allow SSH from admin public IP only"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.admin_allowed_cidr
}

resource "aws_vpc_security_group_ingress_rule" "admin_wireguard" {
  security_group_id = aws_security_group.admin.id
  description       = "Allow WireGuard UDP from dynamic local public IPs"
  ip_protocol       = "udp"
  from_port         = var.wireguard_port
  to_port           = var.wireguard_port
  cidr_ipv4         = var.wireguard_allowed_cidr
}

resource "aws_vpc_security_group_ingress_rule" "admin_icmp_tunnel" {
  security_group_id = aws_security_group.admin.id
  description       = "Allow ICMP from WireGuard tunnel CIDR"
  ip_protocol       = "icmp"
  from_port         = -1
  to_port           = -1
  cidr_ipv4         = var.wireguard_tunnel_cidr
}

resource "aws_vpc_security_group_egress_rule" "admin_all_outbound" {
  security_group_id = aws_security_group.admin.id
  description       = "Allow outbound traffic for tunnel routing"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "monitoring" {
  name        = "${var.name_prefix}-monitoring-sg"
  description = "Security group for private monitoring instance"
  vpc_id      = var.vpc_id
  tags        = merge(var.common_tags, { Name = "${var.name_prefix}-monitoring-sg", Role = "cloud-monitoring" })
}

resource "aws_vpc_security_group_ingress_rule" "monitoring_ssh_from_tunnel_gateway" {
  security_group_id            = aws_security_group.monitoring.id
  description                  = "Allow SSH from tunnel gateway"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.admin.id
}

resource "aws_vpc_security_group_ingress_rule" "monitoring_icmp_from_tunnel_gateway" {
  security_group_id            = aws_security_group.monitoring.id
  description                  = "Allow ICMP from tunnel gateway"
  ip_protocol                  = "icmp"
  from_port                    = -1
  to_port                      = -1
  referenced_security_group_id = aws_security_group.admin.id
}

resource "aws_vpc_security_group_ingress_rule" "monitoring_from_tunnel" {
  security_group_id = aws_security_group.monitoring.id
  description       = "Allow Prometheus/Grafana from WireGuard tunnel CIDR"
  ip_protocol       = "tcp"
  from_port         = 3000
  to_port           = 9090
  cidr_ipv4         = var.wireguard_tunnel_cidr
}

resource "aws_vpc_security_group_ingress_rule" "monitoring_icmp_from_onprem" {
  for_each          = toset(var.onprem_cidr_blocks)
  security_group_id = aws_security_group.monitoring.id
  description       = "Allow ICMP from on-prem CIDRs"
  ip_protocol       = "icmp"
  from_port         = -1
  to_port           = -1
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_egress_rule" "monitoring_all_outbound" {
  security_group_id = aws_security_group.monitoring.id
  description       = "Allow outbound traffic from monitoring"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "ai" {
  name        = "${var.name_prefix}-ai-sg"
  description = "Security group for optional AI analysis service"
  vpc_id      = var.vpc_id
  tags        = merge(var.common_tags, { Name = "${var.name_prefix}-ai-sg", Role = "ai-analysis" })
}

resource "aws_vpc_security_group_ingress_rule" "ai_from_monitoring" {
  security_group_id            = aws_security_group.ai.id
  description                  = "Allow AI service traffic from monitoring"
  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000
  referenced_security_group_id = aws_security_group.monitoring.id
}

resource "aws_vpc_security_group_egress_rule" "ai_all_outbound" {
  security_group_id = aws_security_group.ai.id
  description       = "Allow outbound traffic from AI"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "private" {
  name        = "${var.name_prefix}-private-services-sg"
  description = "Security group for future private services"
  vpc_id      = var.vpc_id
  tags        = merge(var.common_tags, { Name = "${var.name_prefix}-private-services-sg", Role = "private-services" })
}

resource "aws_vpc_security_group_ingress_rule" "private_from_vpc" {
  security_group_id = aws_security_group.private.id
  description       = "Allow internal VPC service-to-service traffic"
  ip_protocol       = "tcp"
  from_port         = 0
  to_port           = 65535
  cidr_ipv4         = var.vpc_cidr
}

resource "aws_vpc_security_group_egress_rule" "private_all_outbound" {
  security_group_id = aws_security_group.private.id
  description       = "Allow outbound traffic from private services"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}


resource "aws_vpc_security_group_ingress_rule" "tunnel_gateway_nat_from_monitoring" {
  security_group_id = aws_security_group.admin.id
  description       = "Allow monitoring subnet to use the tunnel gateway as a NAT/routing instance"
  ip_protocol       = "-1"
  cidr_ipv4         = var.monitoring_subnet_cidr
}
