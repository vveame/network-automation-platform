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
