data "aws_caller_identity" "current" {}

locals {
  generated_bucket_name = "${var.name_prefix}-artifacts-${data.aws_caller_identity.current.account_id}"
  bucket_name           = var.bucket_name_override != null ? var.bucket_name_override : local.generated_bucket_name
}

resource "aws_s3_bucket" "artifacts" {
  bucket = local.bucket_name

  tags = merge(var.common_tags, {
    Name = local.bucket_name
    Role = "logs-metrics-ai-artifacts"
  })
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "expire-validation-artifacts"
    status = "Enabled"

    filter {
      prefix = "validation-artifacts/"
    }

    expiration {
      days = var.validation_artifact_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  rule {
    id     = "expire-processed-summaries"
    status = "Enabled"

    filter {
      prefix = "processed-summaries/"
    }

    expiration {
      days = var.processed_summary_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  rule {
    id     = "expire-anomaly-results"
    status = "Enabled"

    filter {
      prefix = "anomaly-results/"
    }

    expiration {
      days = var.anomaly_result_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  rule {
    id     = "expire-old-latest-analyzer-versions"
    status = "Enabled"

    filter {
      prefix = "latest/analyzer/"
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
  
  rule {
    id     = "expire-old-latest-validation-artifact-versions"
    status = "Enabled"

    filter {
      prefix = "latest/validation-artifacts/"
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}