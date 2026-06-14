variable "enable_compute" {
  description = "Legacy switch. If true, creates the tunnel gateway and the combined monitoring/AI instance. Prefer separate enable_* variables."
  type        = bool
  default     = false
}

variable "enable_tunnel_gateway" {
  description = "Create the public EC2 tunnel gateway used for the hybrid WireGuard tunnel."
  type        = bool
  default     = false
}

variable "enable_monitoring_instance" {
  description = "Create the private EC2 instance hosting both monitoring and AI analysis."
  type        = bool
  default     = false
}

variable "enable_tunnel_gateway_nat_for_monitoring" {
  description = "Use the tunnel gateway as a low-cost NAT/routing instance for the monitoring/AI subnet."
  type        = bool
  default     = true
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
  description = "EC2 instance type used for lab instances."
  type        = string
  default     = "t3.micro"
}

variable "admin_public_key" {
  description = "Public SSH key used to create an AWS key pair for EC2 access. Keep null if compute is disabled."
  type        = string
  default     = null
}

variable "public_subnet_id" {
  description = "Public subnet ID for the tunnel gateway."
  type        = string
}

variable "monitoring_subnet_id" {
  description = "Monitoring/AI subnet ID for the combined monitoring and AI instance."
  type        = string
}

variable "monitoring_route_table_id" {
  description = "Monitoring/AI route table ID."
  type        = string
}

variable "monitoring_subnet_cidr" {
  description = "Monitoring/AI subnet CIDR used by the NAT/routing bootstrap on the tunnel gateway."
  type        = string
}

variable "onprem_cidr_blocks" {
  description = "Local/on-premises CIDR blocks reachable through the EC2 tunnel."
  type        = list(string)
  default     = []
}

variable "admin_security_group_id" {
  description = "Security group ID for the tunnel gateway."
  type        = string
}

variable "monitoring_security_group_id" {
  description = "Security group ID for the combined monitoring and AI instance."
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
}

variable "vpc_cidr" {
  description = "AWS VPC CIDR used by tunnel gateway forwarding rules."
  type        = string
}

variable "wireguard_port" {
  description = "WireGuard UDP port used by the tunnel gateway."
  type        = number
}
