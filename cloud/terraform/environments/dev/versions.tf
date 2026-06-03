terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

variable "storage_bucket_name_override" {
  description = "Optional custom S3 bucket name for logs, metrics, AI outputs and reports. If null, a deterministic name is generated."
  type        = string
  default     = null
}
