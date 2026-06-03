variable "name_prefix" {
  description = "Prefix used for naming AWS resources."
  type        = string
}

variable "bucket_name_override" {
  description = "Optional custom S3 bucket name. If null, a deterministic name is generated using the AWS account ID."
  type        = string
  default     = null
}

variable "common_tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
}
