variable "name_prefix" {
  description = "Prefix used for naming AWS resources."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the AWS VPC."
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet."
  type        = string
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet."
  type        = string
}

variable "monitoring_subnet_cidr" {
  description = "CIDR block for the monitoring and analysis subnet."
  type        = string
}

variable "availability_zone" {
  description = "Availability zone used for the first cloud baseline."
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
}
