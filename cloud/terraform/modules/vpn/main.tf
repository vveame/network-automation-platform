resource "aws_customer_gateway" "onprem" {
  count = var.enable_vpn ? 1 : 0

  bgp_asn    = var.onprem_bgp_asn
  ip_address = var.onprem_public_ip
  type       = "ipsec.1"

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-onprem-cgw"
    Role = "onprem-customer-gateway"
  })
}

resource "aws_vpn_gateway" "main" {
  count = var.enable_vpn ? 1 : 0

  vpc_id          = var.vpc_id
  amazon_side_asn = var.aws_bgp_asn

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-vgw"
    Role = "aws-vpn-gateway"
  })
}

resource "aws_vpn_connection" "main" {
  count = var.enable_vpn ? 1 : 0

  customer_gateway_id = aws_customer_gateway.onprem[0].id
  vpn_gateway_id      = aws_vpn_gateway.main[0].id
  type                = "ipsec.1"
  static_routes_only  = true

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-site-to-site-vpn"
    Role = "hybrid-connectivity"
  })
}

resource "aws_vpn_connection_route" "onprem" {
  for_each = var.enable_vpn ? toset(var.onprem_cidr_blocks) : toset([])

  vpn_connection_id      = aws_vpn_connection.main[0].id
  destination_cidr_block = each.value
}

resource "aws_route" "public_to_onprem" {
  for_each = var.enable_vpn ? toset(var.onprem_cidr_blocks) : toset([])

  route_table_id         = var.public_route_table_id
  destination_cidr_block = each.value
  gateway_id             = aws_vpn_gateway.main[0].id
}

resource "aws_route" "private_to_onprem" {
  for_each = var.enable_vpn ? toset(var.onprem_cidr_blocks) : toset([])

  route_table_id         = var.private_route_table_id
  destination_cidr_block = each.value
  gateway_id             = aws_vpn_gateway.main[0].id
}

resource "aws_route" "monitoring_to_onprem" {
  for_each = var.enable_vpn ? toset(var.onprem_cidr_blocks) : toset([])

  route_table_id         = var.monitoring_route_table_id
  destination_cidr_block = each.value
  gateway_id             = aws_vpn_gateway.main[0].id
}
