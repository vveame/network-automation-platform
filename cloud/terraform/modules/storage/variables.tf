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
