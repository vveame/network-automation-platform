variable "project_name" {
  description = "Project name used for resource naming and tagging."
  type        = string
  default     = "network-automation-platform"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region used for the cloud baseline."
  type        = string
  default     = "eu-north-1"
}

variable "aws_profile" {
  description = "Local AWS CLI profile used by Terraform. Set to null if using environment variables or instance role credentials."
  type        = string
  default     = null
}

variable "owner" {
  description = "Owner tag for resources."
  type        = string
  default     = "wiam"
}

variable "vpc_cidr" {
  description = "CIDR block for the AWS VPC."
  type        = string
  default     = "10.50.0.0/16"
}

variable "availability_zone" {
  description = "Availability zone used for the first cloud baseline."
  type        = string
  default     = "eu-north-1a"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet."
  type        = string
  default     = "10.50.10.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet."
  type        = string
  default     = "10.50.20.0/24"
}

variable "monitoring_subnet_cidr" {
  description = "CIDR block for the monitoring and AI subnet."
  type        = string
  default     = "10.50.30.0/24"
}

variable "admin_allowed_cidr" {
  description = "Public CIDR allowed to access SSH on the tunnel gateway. Use a /32."
  type        = string
  default     = "0.0.0.0/32"
}

variable "wireguard_allowed_cidr" {
  description = "CIDR allowed to reach WireGuard UDP on the tunnel gateway. Use 0.0.0.0/0 if the local public IP is unstable."
  type        = string
  default     = "0.0.0.0/0"
}

variable "enable_compute" {
  description = "Legacy compute switch. Prefer the separate enable_tunnel_gateway and enable_monitoring_instance variables."
  type        = bool
  default     = false
}

variable "enable_tunnel_gateway" {
  description = "Create the public EC2 WireGuard tunnel gateway. Disabled by default to avoid cost."
  type        = bool
  default     = false
}

variable "enable_monitoring_instance" {
  description = "Create the private cloud monitoring EC2 instance. Disabled by default to avoid cost."
  type        = bool
  default     = false
}

variable "enable_ai_instance" {
  description = "Create the optional private AI EC2 instance. Disabled by default to avoid cost."
  type        = bool
  default     = false
}

variable "enable_tunnel_gateway_nat_for_monitoring" {
  description = "Use the tunnel gateway as a low-cost NAT/routing instance for monitoring subnet outbound access."
  type        = bool
  default     = true
}

variable "wireguard_tunnel_cidr" {
  description = "Small tunnel CIDR used by WireGuard between AWS and the local edge path."
  type        = string
  default     = "10.255.0.0/30"
}

variable "wireguard_port" {
  description = "WireGuard UDP listen port on the EC2 tunnel gateway."
  type        = number
  default     = 51820
}

variable "compute_instance_type" {
  description = "EC2 instance type used for cloud lab instances."
  type        = string
  default     = "t3.micro"
}

variable "compute_ami_ssm_parameter" {
  description = "SSM public parameter used to retrieve the latest Amazon Linux 2023 AMI."
  type        = string
  default     = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

variable "admin_public_key" {
  description = "Public SSH key used to create an AWS key pair for EC2 access. Keep null if compute is disabled."
  type        = string
  default     = null
}

variable "enable_vpn" {
  description = "Whether to create AWS Site-to-Site VPN resources. Disabled by default."
  type        = bool
  default     = false
}

variable "onprem_public_ip" {
  description = "Public IP address of the on-prem customer gateway device. Required only when enable_vpn is true."
  type        = string
  default     = null
}

variable "onprem_cidr_blocks" {
  description = "Local/on-premises CIDR blocks reachable through the EC2 tunnel or future VPN."
  type        = list(string)
  default     = ["10.200.0.0/24", "172.16.0.0/16"]
}

variable "onprem_bgp_asn" {
  description = "BGP ASN for the on-prem customer gateway."
  type        = number
  default     = 65010
}

variable "aws_bgp_asn" {
  description = "AWS side ASN for the virtual private gateway."
  type        = number
  default     = 64512
}

variable "storage_bucket_name_override" {
  description = "Optional custom S3 bucket name. If null, the module generates a bucket name."
  type        = string
  default     = null
}

variable "validation_artifact_retention_days" {
  description = "Number of days to retain validation artifact objects in S3."
  type        = number
  default     = 30
}

variable "noncurrent_version_retention_days" {
  description = "Number of days to retain noncurrent object versions in the versioned S3 bucket."
  type        = number
  default     = 7
}

variable "processed_summary_retention_days" {
  description = "Number of days to retain processed analyzer summaries in S3."
  type        = number
  default     = 90
}

variable "anomaly_result_retention_days" {
  description = "Number of days to retain anomaly result outputs in S3."
  type        = number
  default     = 90
}
