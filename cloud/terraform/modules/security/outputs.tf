output "admin_security_group_id" { value = aws_security_group.admin.id }
output "monitoring_security_group_id" { value = aws_security_group.monitoring.id }
output "ai_security_group_id" { value = aws_security_group.ai.id }
output "private_security_group_id" { value = aws_security_group.private.id }
