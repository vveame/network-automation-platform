output "bastion_instance_id" {
  description = "ID of the bastion/admin instance, if compute is enabled."
  value       = try(aws_instance.bastion[0].id, null)
}

output "bastion_public_ip" {
  description = "Public IP of the bastion/admin instance, if compute is enabled."
  value       = try(aws_instance.bastion[0].public_ip, null)
}

output "monitoring_instance_id" {
  description = "ID of the monitoring placeholder instance, if compute is enabled."
  value       = try(aws_instance.monitoring[0].id, null)
}

output "monitoring_private_ip" {
  description = "Private IP of the monitoring placeholder instance, if compute is enabled."
  value       = try(aws_instance.monitoring[0].private_ip, null)
}

output "ai_instance_id" {
  description = "ID of the AI analysis placeholder instance, if compute is enabled."
  value       = try(aws_instance.ai[0].id, null)
}

output "ai_private_ip" {
  description = "Private IP of the AI analysis placeholder instance, if compute is enabled."
  value       = try(aws_instance.ai[0].private_ip, null)
}
