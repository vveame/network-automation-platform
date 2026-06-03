output "admin_security_group_id" {
  description = "Security group ID for future admin/bastion access."
  value       = aws_security_group.admin.id
}

output "monitoring_security_group_id" {
  description = "Security group ID for future monitoring services."
  value       = aws_security_group.monitoring.id
}

output "ai_security_group_id" {
  description = "Security group ID for future AI analysis service."
  value       = aws_security_group.ai.id
}

output "private_security_group_id" {
  description = "Security group ID for future private services."
  value       = aws_security_group.private.id
}
