output "project_name" {
  description = "Project name used by this Terraform environment."
  value       = var.project_name
}

output "environment" {
  description = "Terraform environment name."
  value       = var.environment
}

output "aws_region" {
  description = "AWS region configured for this environment."
  value       = var.aws_region
}

output "vpc_id" {
  description = "AWS VPC ID."
  value       = module.network.vpc_id
}

output "vpc_cidr" {
  description = "AWS VPC CIDR block."
  value       = module.network.vpc_cidr
}

output "public_subnet_id" {
  description = "Public subnet ID."
  value       = module.network.public_subnet_id
}

output "private_subnet_id" {
  description = "Private subnet ID."
  value       = module.network.private_subnet_id
}

output "monitoring_subnet_id" {
  description = "Monitoring subnet ID."
  value       = module.network.monitoring_subnet_id
}

output "internet_gateway_id" {
  description = "Internet Gateway ID."
  value       = module.network.internet_gateway_id
}

output "public_route_table_id" {
  description = "Public route table ID."
  value       = module.network.public_route_table_id
}

output "private_route_table_id" {
  description = "Private route table ID."
  value       = module.network.private_route_table_id
}

output "monitoring_route_table_id" {
  description = "Monitoring route table ID."
  value       = module.network.monitoring_route_table_id
}

output "admin_security_group_id" {
  description = "Security group ID for tunnel gateway access."
  value       = module.security.admin_security_group_id
}

output "monitoring_security_group_id" {
  description = "Security group ID for monitoring services."
  value       = module.security.monitoring_security_group_id
}

output "ai_security_group_id" {
  description = "Security group ID for future AI analysis service."
  value       = module.security.ai_security_group_id
}

output "private_security_group_id" {
  description = "Security group ID for future private services."
  value       = module.security.private_security_group_id
}

output "artifacts_bucket_name" {
  description = "Name of the S3 bucket used for platform artifacts."
  value       = module.storage.artifacts_bucket_name
}

output "artifacts_bucket_arn" {
  description = "ARN of the S3 bucket used for platform artifacts."
  value       = module.storage.artifacts_bucket_arn
}

output "tunnel_gateway_instance_id" {
  description = "ID of the public EC2 tunnel gateway, if enabled."
  value       = module.compute.tunnel_gateway_instance_id
}

output "tunnel_gateway_public_ip" {
  description = "Public IP of the public EC2 tunnel gateway, if enabled."
  value       = module.compute.tunnel_gateway_public_ip
}

output "tunnel_gateway_private_ip" {
  description = "Private IP of the public EC2 tunnel gateway, if enabled."
  value       = module.compute.tunnel_gateway_private_ip
}

output "monitoring_instance_id" {
  description = "ID of the private cloud monitoring instance, if enabled."
  value       = module.compute.monitoring_instance_id
}

output "monitoring_private_ip" {
  description = "Private IP of the private cloud monitoring instance, if enabled."
  value       = module.compute.monitoring_private_ip
}

output "ai_instance_id" {
  description = "ID of the optional AI instance, if enabled."
  value       = module.compute.ai_instance_id
}

output "ai_private_ip" {
  description = "Private IP of the optional AI instance, if enabled."
  value       = module.compute.ai_private_ip
}

output "bastion_instance_id" {
  description = "Legacy alias for tunnel gateway instance ID."
  value       = module.compute.bastion_instance_id
}

output "bastion_public_ip" {
  description = "Legacy alias for tunnel gateway public IP."
  value       = module.compute.bastion_public_ip
}

output "vpn_enabled" {
  description = "Whether AWS Site-to-Site VPN resources are enabled."
  value       = module.vpn.vpn_enabled
}

output "customer_gateway_id" {
  description = "Customer Gateway ID, if VPN is enabled."
  value       = module.vpn.customer_gateway_id
}

output "vpn_gateway_id" {
  description = "Virtual Private Gateway ID, if VPN is enabled."
  value       = module.vpn.vpn_gateway_id
}

output "vpn_connection_id" {
  description = "Site-to-Site VPN connection ID, if VPN is enabled."
  value       = module.vpn.vpn_connection_id
}

output "vpn_tunnel_1_address" {
  description = "AWS tunnel 1 outside address, if VPN is enabled."
  value       = module.vpn.vpn_tunnel_1_address
}

output "vpn_tunnel_2_address" {
  description = "AWS tunnel 2 outside address, if VPN is enabled."
  value       = module.vpn.vpn_tunnel_2_address
}
