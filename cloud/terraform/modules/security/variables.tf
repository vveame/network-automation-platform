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
  description = "Public CIDR allowed to access cloud admin services such as SSH."
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
}
