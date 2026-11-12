variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "bucket_prefix" {
  description = "Prefix for all S3 bucket names"
  type        = string
  default     = "imageflow"
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for S3 encryption"
  type        = string
}

variable "cloudfront_oac_arn" {
  description = "ARN of the CloudFront Origin Access Control"
  type        = string
  default     = ""
}
