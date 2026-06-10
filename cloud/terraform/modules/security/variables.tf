variable "name_prefix" {
  description = "Prefix used for naming AWS resources."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where security groups will be created."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC."
  type        = string
}

variable "admin_allowed_cidr" {
  description = "Public CIDR allowed to access SSH on the tunnel gateway. Use a /32."
  type        = string
}

variable "wireguard_allowed_cidr" {
  description = "CIDR allowed to reach WireGuard UDP on the tunnel gateway."
  type        = string
}

variable "wireguard_port" {
  description = "UDP port used by the public EC2 tunnel gateway."
  type        = number
  default     = 51820
}

variable "wireguard_tunnel_cidr" {
  description = "CIDR of the WireGuard tunnel network."
  type        = string
  default     = "10.255.0.0/30"
}

variable "onprem_cidr_blocks" {
  description = "Local/on-premises CIDR blocks reachable through the EC2 tunnel."
  type        = list(string)
  default     = []
}

variable "common_tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
}


variable "monitoring_subnet_cidr" {
  description = "Monitoring subnet CIDR allowed to use the tunnel gateway as a NAT/routing instance."
  type        = string
}
