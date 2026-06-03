variable "enable_vpn" {
  description = "Whether to create AWS Site-to-Site VPN resources. Disabled by default to avoid cost and accidental exposure."
  type        = bool
  default     = false
}

variable "name_prefix" {
  description = "Prefix used for naming AWS resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the VPN Gateway will be attached."
  type        = string
}

variable "public_route_table_id" {
  description = "Public route table ID."
  type        = string
}

variable "private_route_table_id" {
  description = "Private route table ID."
  type        = string
}

variable "monitoring_route_table_id" {
  description = "Monitoring route table ID."
  type        = string
}

variable "onprem_public_ip" {
  description = "Public IP address of the on-prem customer gateway device. Required only when enable_vpn is true."
  type        = string
  default     = null

  validation {
    condition     = !var.enable_vpn || (var.onprem_public_ip != null && length(trimspace(var.onprem_public_ip)) > 0)
    error_message = "onprem_public_ip must be provided when enable_vpn is true."
  }
}

variable "onprem_cidr_blocks" {
  description = "On-premises CIDR blocks reachable through the VPN."
  type        = list(string)
  default     = ["10.200.0.0/24", "172.16.0.0/16"]
}

variable "onprem_bgp_asn" {
  description = "BGP ASN for the on-prem customer gateway. Used even with static VPN configuration."
  type        = number
  default     = 65010
}

variable "aws_bgp_asn" {
  description = "AWS side ASN for the virtual private gateway."
  type        = number
  default     = 64512
}

variable "common_tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
}
