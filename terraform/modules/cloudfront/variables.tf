variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "frontend_bucket_regional_domain" {
  description = "Regional domain name of the frontend S3 bucket"
  type        = string
}

variable "processed_bucket_regional_domain" {
  description = "Regional domain name of the processed images S3 bucket"
  type        = string
}

variable "waf_acl_arn" {
  description = "ARN of the WAF web ACL to associate with CloudFront"
  type        = string
  default     = ""
}

variable "price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100"
}

variable "geo_restriction_type" {
  description = "Geo restriction type (none, whitelist, blacklist)"
  type        = string
  default     = "none"
}

variable "geo_restriction_locations" {
  description = "List of country codes for geo restriction"
  type        = list(string)
  default     = []
}
