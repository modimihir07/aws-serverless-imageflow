terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project     = "Serverless-ImageFlow"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

locals {
  bucket_prefix = "imageflow-${var.environment}"
  table_name    = "ImageFlow-Metadata-${var.environment}"
}

module "kms" {
  source = "../../modules/kms"

  environment  = var.environment
  alias_prefix = "imageflow"
}

module "s3" {
  source = "../../modules/s3"

  environment        = var.environment
  bucket_prefix      = local.bucket_prefix
  kms_key_arn        = module.kms.key_arn
  cloudfront_oac_arn = module.cloudfront.frontend_oac_arn
}

module "dynamodb" {
  source = "../../modules/dynamodb"

  environment = var.environment
  table_name  = local.table_name
  kms_key_arn = module.kms.key_arn
}

module "iam" {
  source = "../../modules/iam"

  environment          = var.environment
  region               = var.region
  uploads_bucket_arn   = module.s3.uploads_bucket_arn
  processed_bucket_arn = module.s3.processed_bucket_arn
  dynamodb_table_arn   = module.dynamodb.table_arn
  kms_key_arn          = module.kms.key_arn
}

module "lambda" {
  source = "../../modules/lambda"

  environment            = var.environment
  processor_package_path = var.processor_package_path
  api_package_path       = var.api_package_path
  processor_role_arn     = module.iam.image_processor_role_arn
  api_role_arn           = module.iam.image_api_role_arn
  processed_bucket_id    = module.s3.processed_bucket_id
  uploads_bucket_id      = module.s3.uploads_bucket_id
  uploads_bucket_arn     = module.s3.uploads_bucket_arn
  dynamodb_table_name    = module.dynamodb.table_name
  kms_key_arn            = module.kms.key_arn
  api_gateway_exec_arn   = module.api_gateway.execution_arn
}

module "api_gateway" {
  source = "../../modules/api-gateway"

  environment              = var.environment
  lambda_invoke_arn        = module.lambda.image_api_function_arn
  cloudwatch_log_group_arn = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/api-gateway/ImageFlow"
}

module "cloudfront" {
  source = "../../modules/cloudfront"

  environment                      = var.environment
  frontend_bucket_regional_domain  = module.s3.frontend_bucket_id
  processed_bucket_regional_domain = module.s3.processed_bucket_id
  price_class                      = var.cloudfront_price_class
}

data "aws_caller_identity" "current" {}

output "cloudfront_frontend_url" {
  value = "https://${module.cloudfront.frontend_distribution_domain}"
}

output "cloudfront_images_url" {
  value = "https://${module.cloudfront.images_distribution_domain}"
}

output "api_gateway_url" {
  value = module.api_gateway.api_url
}

output "dynamodb_table" {
  value = module.dynamodb.table_name
}

output "uploads_bucket" {
  value = module.s3.uploads_bucket_id
}
