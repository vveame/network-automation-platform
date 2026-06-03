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
  description = "Public CIDR allowed to access cloud admin services such as SSH. Use a /32 for a single admin public IP."
  type        = string
  default     = "0.0.0.0/32"
}
