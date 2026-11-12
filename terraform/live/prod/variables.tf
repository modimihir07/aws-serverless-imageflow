variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "processor_package_path" {
  description = "Path to the image-processor Lambda zip package"
  type        = string
  default     = "../../lambda/image-processor/dist/processor.zip"
}

variable "api_package_path" {
  description = "Path to the image-api Lambda zip package"
  type        = string
  default     = "../../lambda/image-api/dist/api.zip"
}

variable "cognito_domain" {
  description = "Optional domain prefix for Cognito Hosted UI when re-enabled from future scope"
  type        = string
  default     = null
}

variable "cognito_callback_urls" {
  description = "Callback URLs for Cognito app client"
  type        = list(string)
  default     = ["https://YOUR_DOMAIN"]
}

variable "cognito_logout_urls" {
  description = "Logout URLs for Cognito app client"
  type        = list(string)
  default     = ["https://YOUR_DOMAIN"]
}

variable "cloudfront_price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_All"
}
