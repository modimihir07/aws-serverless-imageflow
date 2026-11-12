variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "uploads_bucket_arn" {
  description = "ARN of the uploads S3 bucket"
  type        = string
}

variable "processed_bucket_arn" {
  description = "ARN of the processed S3 bucket"
  type        = string
}

variable "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key"
  type        = string
}

variable "image_processor_lambda_arn" {
  description = "ARN of the image processor Lambda function"
  type        = string
  default     = ""
}

variable "image_api_lambda_arn" {
  description = "ARN of the image API Lambda function"
  type        = string
  default     = ""
}
