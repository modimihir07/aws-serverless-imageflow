variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "lambda_invoke_arn" {
  description = "Invoke ARN of the image API Lambda function"
  type        = string
}

variable "cognito_user_pool_arn" {
  description = "Optional ARN of the Cognito user pool (null when auth is disabled/future scope)"
  type        = string
  default     = null
}

variable "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group for API Gateway"
  type        = string
}
