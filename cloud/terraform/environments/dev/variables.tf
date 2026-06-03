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
