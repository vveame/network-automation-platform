variable "enable_compute" {
  description = "Whether to create EC2 placeholder instances. Disabled by default to avoid unnecessary costs."
  type        = bool
  default     = false
}

variable "name_prefix" {
  description = "Prefix used for naming AWS resources."
  type        = string
}

variable "ami_ssm_parameter" {
  description = "SSM public parameter used to retrieve the latest Amazon Linux 2023 AMI."
  type        = string
  default     = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

variable "instance_type" {
  description = "EC2 instance type used for placeholder instances."
  type        = string
  default     = "t3.micro"
}

variable "admin_public_key" {
  description = "Public SSH key used to create an AWS key pair for EC2 access. Keep null if compute is disabled."
  type        = string
  default     = null
}

variable "public_subnet_id" {
  description = "Public subnet ID for the bastion/admin instance."
  type        = string
}

variable "monitoring_subnet_id" {
  description = "Monitoring subnet ID for monitoring and AI placeholder instances."
  type        = string
}

variable "admin_security_group_id" {
  description = "Security group ID for the bastion/admin instance."
  type        = string
}

variable "monitoring_security_group_id" {
  description = "Security group ID for the monitoring instance."
  type        = string
}

variable "ai_security_group_id" {
  description = "Security group ID for the AI analysis instance."
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
}
