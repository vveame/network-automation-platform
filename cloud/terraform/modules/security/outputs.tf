output "admin_security_group_id" {
  value = aws_security_group.admin.id
}

output "monitoring_security_group_id" {
  value = aws_security_group.monitoring.id
}
