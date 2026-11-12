variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "alias_prefix" {
  description = "Prefix for the KMS key alias"
  type        = string
  default     = "imageflow"
}
