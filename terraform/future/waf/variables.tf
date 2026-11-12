variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "rate_limit" {
  description = "Rate limit per IP (requests per 5-minute window)"
  type        = number
  default     = 5000
}

variable "cloudfront_arn" {
  description = "ARN of the CloudFront distribution to associate with WAF"
  type        = string
  default     = ""
}
