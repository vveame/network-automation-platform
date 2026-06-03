resource "aws_security_group" "admin" {
  name        = "${var.name_prefix}-admin-sg"
  description = "Admin access security group for future bastion or management instance"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-admin-sg"
    Role = "admin-access"
  })
}

resource "aws_vpc_security_group_ingress_rule" "admin_ssh" {
  security_group_id = aws_security_group.admin.id

  description = "Allow SSH from the configured admin public IP only"
  ip_protocol = "tcp"
  from_port   = 22
  to_port     = 22
  cidr_ipv4   = var.admin_allowed_cidr
}

resource "aws_vpc_security_group_egress_rule" "admin_all_outbound" {
  security_group_id = aws_security_group.admin.id

  description = "Allow outbound traffic for admin instance updates and package access"
  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_security_group" "monitoring" {
  name        = "${var.name_prefix}-monitoring-sg"
  description = "Monitoring security group for future Prometheus and Grafana services"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-monitoring-sg"
    Role = "monitoring"
  })
}

resource "aws_vpc_security_group_ingress_rule" "monitoring_grafana" {
  security_group_id = aws_security_group.monitoring.id

  description = "Allow Grafana access from the configured admin public IP only"
  ip_protocol = "tcp"
  from_port   = 3000
  to_port     = 3000
  cidr_ipv4   = var.admin_allowed_cidr
}

resource "aws_vpc_security_group_ingress_rule" "monitoring_prometheus" {
  security_group_id = aws_security_group.monitoring.id

  description = "Allow Prometheus access from the configured admin public IP only"
  ip_protocol = "tcp"
  from_port   = 9090
  to_port     = 9090
  cidr_ipv4   = var.admin_allowed_cidr
}

resource "aws_vpc_security_group_ingress_rule" "monitoring_from_vpc" {
  security_group_id = aws_security_group.monitoring.id

  description = "Allow internal VPC metrics traffic to monitoring services"
  ip_protocol = "tcp"
  from_port   = 9100
  to_port     = 9100
  cidr_ipv4   = var.vpc_cidr
}

resource "aws_vpc_security_group_egress_rule" "monitoring_all_outbound" {
  security_group_id = aws_security_group.monitoring.id

  description = "Allow outbound traffic from monitoring services"
  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_security_group" "ai" {
  name        = "${var.name_prefix}-ai-sg"
  description = "AI analysis security group for future anomaly detection service"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-ai-sg"
    Role = "ai-analysis"
  })
}

resource "aws_vpc_security_group_ingress_rule" "ai_from_monitoring" {
  security_group_id = aws_security_group.ai.id

  description                  = "Allow AI service traffic from monitoring security group"
  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000
  referenced_security_group_id = aws_security_group.monitoring.id
}

resource "aws_vpc_security_group_egress_rule" "ai_all_outbound" {
  security_group_id = aws_security_group.ai.id

  description = "Allow outbound traffic from AI service"
  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_security_group" "private" {
  name        = "${var.name_prefix}-private-services-sg"
  description = "Private services security group for future internal cloud services"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-private-services-sg"
    Role = "private-services"
  })
}

resource "aws_vpc_security_group_ingress_rule" "private_from_vpc" {
  security_group_id = aws_security_group.private.id

  description = "Allow internal VPC service-to-service traffic"
  ip_protocol = "tcp"
  from_port   = 0
  to_port     = 65535
  cidr_ipv4   = var.vpc_cidr
}

resource "aws_vpc_security_group_egress_rule" "private_all_outbound" {
  security_group_id = aws_security_group.private.id

  description = "Allow outbound traffic from private services"
  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "monitoring_ssh_from_admin_sg" {
  security_group_id = aws_security_group.monitoring.id

  description                  = "Allow SSH to monitoring instance from admin/bastion security group"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.admin.id
}

resource "aws_vpc_security_group_ingress_rule" "ai_ssh_from_admin_sg" {
  security_group_id = aws_security_group.ai.id

  description                  = "Allow SSH to AI instance from admin/bastion security group"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.admin.id
}
