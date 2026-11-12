variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "cognito_domain" {
  description = "Domain prefix for the Cognito Hosted UI (must be globally unique)"
  type        = string
}

variable "callback_urls" {
  description = "List of callback URLs for the Cognito app client"
  type        = list(string)
  default     = ["http://localhost:3000/"]
}

variable "logout_urls" {
  description = "List of logout URLs for the Cognito app client"
  type        = list(string)
  default     = ["http://localhost:3000/"]
}

variable "uploads_bucket_arn" {
  description = "ARN of the uploads S3 bucket"
  type        = string
}
