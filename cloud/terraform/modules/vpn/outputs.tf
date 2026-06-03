output "vpn_enabled" {
  description = "Whether VPN resources are enabled."
  value       = var.enable_vpn
}

output "customer_gateway_id" {
  description = "Customer Gateway ID, if VPN is enabled."
  value       = try(aws_customer_gateway.onprem[0].id, null)
}

output "vpn_gateway_id" {
  description = "Virtual Private Gateway ID, if VPN is enabled."
  value       = try(aws_vpn_gateway.main[0].id, null)
}

output "vpn_connection_id" {
  description = "Site-to-Site VPN connection ID, if VPN is enabled."
  value       = try(aws_vpn_connection.main[0].id, null)
}

output "vpn_tunnel_1_address" {
  description = "AWS tunnel 1 outside address, if VPN is enabled."
  value       = try(aws_vpn_connection.main[0].tunnel1_address, null)
}

output "vpn_tunnel_2_address" {
  description = "AWS tunnel 2 outside address, if VPN is enabled."
  value       = try(aws_vpn_connection.main[0].tunnel2_address, null)
}
