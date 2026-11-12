# Terraform Remote State Configuration
#
# Before running terraform init, create the backend S3 bucket:
#   aws s3 mb s3://imageflow-terraform-state-YOUR_ACCOUNT_ID --region us-east-1
#
# Enable bucket encryption and versioning:
#   aws s3api put-bucket-encryption \
#     --bucket imageflow-terraform-state-YOUR_ACCOUNT_ID \
#     --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
#   aws s3api put-bucket-versioning \
#     --bucket imageflow-terraform-state-YOUR_ACCOUNT_ID \
#     --versioning-configuration Status=Enabled
#
# Create the DynamoDB lock table:
#   aws dynamodb create-table \
#     --table-name imageflow-terraform-locks \
#     --attribute-definitions AttributeName=LockID,AttributeType=S \
#     --key-schema AttributeName=LockID,KeyType=HASH \
#     --billing-mode PAY_PER_REQUEST \
#     --region us-east-1
#
# Then copy this block into live/dev/backend.tf and live/prod/backend.tf

# terraform {
#   backend "s3" {
#     bucket         = "imageflow-terraform-state-YOUR_ACCOUNT_ID"
#     key            = "live/dev/terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     dynamodb_table = "imageflow-terraform-locks"
#   }
# }
