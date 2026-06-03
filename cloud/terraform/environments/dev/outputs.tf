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

output "admin_security_group_id" {
  description = "Security group ID for future admin/bastion access."
  value       = module.security.admin_security_group_id
}

output "monitoring_security_group_id" {
  description = "Security group ID for future monitoring services."
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
  description = "Name of the S3 bucket used for logs, metrics, AI outputs and reports."
  value       = module.storage.artifacts_bucket_name
}

output "artifacts_bucket_arn" {
  description = "ARN of the S3 bucket used for logs, metrics, AI outputs and reports."
  value       = module.storage.artifacts_bucket_arn
}
