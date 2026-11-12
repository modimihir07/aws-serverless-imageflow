variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "role_arn" {
  description = "ARN of the IAM role for Step Functions"
  type        = string
}

variable "image_processor_lambda_arn" {
  description = "ARN of the image processor Lambda function"
  type        = string
}

variable "image_api_lambda_arn" {
  description = "ARN of the image API Lambda function"
  type        = string
}

variable "event_bus_name" {
  description = "Name of the EventBridge event bus"
  type        = string
  default     = "default"
}
