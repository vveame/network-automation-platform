locals {
  create_tunnel_gateway      = var.enable_compute || var.enable_tunnel_gateway
  create_monitoring_instance = var.enable_compute || var.enable_monitoring_instance
  create_ai_instance         = var.enable_compute || var.enable_ai_instance
  create_any_instance        = local.create_tunnel_gateway || local.create_monitoring_instance || local.create_ai_instance

  create_key_pair = local.create_any_instance && var.admin_public_key != null && trimspace(var.admin_public_key) != ""
  ssh_key_name    = local.create_key_pair ? aws_key_pair.admin[0].key_name : null
}

# Keep this public SSM parameter lookup.
# It is only used to resolve the latest Amazon Linux 2023 AMI ID.
# This is not related to EC2 SSM Session Manager access.
data "aws_ssm_parameter" "al2023_ami" {
  count = local.create_any_instance ? 1 : 0
  name  = var.ami_ssm_parameter
}

resource "aws_key_pair" "admin" {
  count = local.create_key_pair ? 1 : 0

  key_name   = "${var.name_prefix}-admin-key"
  public_key = var.admin_public_key

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-admin-key"
    Role = "ec2-admin-access"
  })
}

resource "aws_instance" "tunnel_gateway" {
  count = local.create_tunnel_gateway ? 1 : 0

  ami                         = data.aws_ssm_parameter.al2023_ami[0].value
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [var.admin_security_group_id]
  associate_public_ip_address = true
  key_name                    = local.ssh_key_name

  # Required because this instance forwards traffic between:
  # - AWS VPC
  # - WireGuard tunnel
  # - monitoring subnet NAT egress
  source_dest_check = false

  user_data = templatefile("${path.module}/user-data/tunnel-gateway.sh.tftpl", {
    name_prefix            = var.name_prefix
    monitoring_subnet_cidr = var.monitoring_subnet_cidr
    vpc_cidr               = var.vpc_cidr
    wireguard_port         = var.wireguard_port
  })

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-tunnel-gateway"
    Role = "hybrid-ec2-tunnel-gateway"
    Tier = "public"
  })
}

resource "aws_instance" "monitoring" {
  count = local.create_monitoring_instance ? 1 : 0

  ami                         = data.aws_ssm_parameter.al2023_ami[0].value
  instance_type               = var.instance_type
  subnet_id                   = var.monitoring_subnet_id
  vpc_security_group_ids      = [var.monitoring_security_group_id]
  associate_public_ip_address = false
  key_name                    = local.ssh_key_name

  user_data = templatefile("${path.module}/user-data/monitoring.sh.tftpl", {
    name_prefix = var.name_prefix
  })

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-monitoring"
    Role = "cloud-monitoring"
    Tier = "monitoring-ai"
  })
}

resource "aws_instance" "ai" {
  count = local.create_ai_instance ? 1 : 0

  ami                         = data.aws_ssm_parameter.al2023_ami[0].value
  instance_type               = var.instance_type
  subnet_id                   = var.monitoring_subnet_id
  vpc_security_group_ids      = [var.ai_security_group_id]
  associate_public_ip_address = false
  key_name                    = local.ssh_key_name

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-ai"
    Role = "cloud-ai-analysis"
    Tier = "monitoring-ai"
  })
}

resource "aws_route" "monitoring_to_onprem" {
  for_each = local.create_tunnel_gateway ? toset(var.onprem_cidr_blocks) : toset([])

  route_table_id         = var.monitoring_route_table_id
  destination_cidr_block = each.value
  network_interface_id   = aws_instance.tunnel_gateway[0].primary_network_interface_id

  depends_on = [aws_instance.tunnel_gateway]
}

resource "aws_route" "private_to_onprem" {
  for_each = local.create_tunnel_gateway ? toset(var.onprem_cidr_blocks) : toset([])

  route_table_id         = var.private_route_table_id
  destination_cidr_block = each.value
  network_interface_id   = aws_instance.tunnel_gateway[0].primary_network_interface_id

  depends_on = [aws_instance.tunnel_gateway]
}

resource "aws_route" "monitoring_default_via_tunnel_gateway" {
  count = local.create_tunnel_gateway && local.create_monitoring_instance && var.enable_tunnel_gateway_nat_for_monitoring ? 1 : 0

  route_table_id         = var.monitoring_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.tunnel_gateway[0].primary_network_interface_id

  depends_on = [aws_instance.tunnel_gateway]
}
