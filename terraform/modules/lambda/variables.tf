variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "processor_package_path" {
  description = "Path to the image-processor Lambda deployment package zip"
  type        = string
}

variable "api_package_path" {
  description = "Path to the image-api Lambda deployment package zip"
  type        = string
}

variable "processor_role_arn" {
  description = "ARN of the IAM role for the image processor Lambda"
  type        = string
}

variable "api_role_arn" {
  description = "ARN of the IAM role for the image API Lambda"
  type        = string
}

variable "processed_bucket_id" {
  description = "ID of the processed S3 bucket"
  type        = string
}

variable "uploads_bucket_id" {
  description = "ID of the uploads S3 bucket"
  type        = string
}

variable "uploads_bucket_arn" {
  description = "ARN of the uploads S3 bucket"
  type        = string
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key"
  type        = string
}

variable "api_gateway_exec_arn" {
  description = "ARN of the API Gateway execution endpoint"
  type        = string
  default     = ""
}

variable "allowed_origins" {
  description = "Comma-separated list of allowed CORS origins"
  type        = string
  default     = "*"
}
