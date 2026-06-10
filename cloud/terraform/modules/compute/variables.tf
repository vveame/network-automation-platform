variable "enable_compute" {
  description = "Legacy switch. If true, creates tunnel gateway, monitoring and AI instances. Prefer separate enable_* variables."
  type        = bool
  default     = false
}

variable "enable_tunnel_gateway" {
  description = "Create the public EC2 tunnel gateway used for the hybrid WireGuard tunnel."
  type        = bool
  default     = false
}

variable "enable_monitoring_instance" {
  description = "Create the private monitoring EC2 instance."
  type        = bool
  default     = false
}

variable "enable_ai_instance" {
  description = "Create the optional private AI EC2 instance."
  type        = bool
  default     = false
}

variable "enable_tunnel_gateway_nat_for_monitoring" {
  description = "Use the tunnel gateway as a low-cost NAT/routing instance for the monitoring subnet."
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
  description = "Monitoring subnet ID for monitoring and AI instances."
  type        = string
}

variable "private_route_table_id" {
  description = "Private route table ID. Used to route private subnet traffic toward local CIDRs through the tunnel gateway."
  type        = string
}

variable "monitoring_route_table_id" {
  description = "Monitoring route table ID. Used to route monitoring subnet traffic through the tunnel gateway."
  type        = string
}

variable "monitoring_subnet_cidr" {
  description = "Monitoring subnet CIDR used by the NAT/routing bootstrap on the tunnel gateway."
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

variable "vpc_cidr" {
  description = "AWS VPC CIDR used by tunnel gateway forwarding rules."
  type        = string
}

variable "wireguard_port" {
  description = "WireGuard UDP port used by the tunnel gateway."
  type        = number
}
