#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Serverless ImageFlow - Complete Cleanup Script
# =============================================================================
# Usage:
#   ./scripts/cleanup.sh [dev|prod]
#
# WARNING: This will DELETE all resources. Data in S3 and DynamoDB will be lost.
# =============================================================================

ENVIRONMENT="${1:-dev}"
AWS_REGION="${AWS_REGION:-us-east-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "=== Serverless ImageFlow Cleanup ==="
echo "Environment: $ENVIRONMENT"
echo "WARNING: This will destroy all resources!"

read -p "Continue? (y/N): " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
  echo "Cleanup cancelled."
  exit 0
fi

# ---------------------------------------------------------------------------
# Step 1: Empty and delete S3 buckets
# ---------------------------------------------------------------------------
echo ""
echo "--- Step 1: Cleaning S3 buckets ---"
BUCKETS=(
  "imageflow-${ENVIRONMENT}-uploads"
  "imageflow-${ENVIRONMENT}-processed"
  "imageflow-${ENVIRONMENT}-frontend"
  "imageflow-${ENVIRONMENT}-logs"
  "imageflow-${ENVIRONMENT}-lambda-artifacts-${ACCOUNT_ID}"
)

for bucket in "${BUCKETS[@]}"; do
  if aws s3 ls "s3://${bucket}" 2>/dev/null; then
    echo "Emptying $bucket..."
    aws s3 rm "s3://${bucket}" --recursive --quiet 2>/dev/null || true
    aws s3api delete-bucket --bucket "$bucket" --region "$AWS_REGION" 2>/dev/null || true
    echo "  Deleted: $bucket"
  fi
done

# ---------------------------------------------------------------------------
# Step 2: Delete CloudFormation stack
# ---------------------------------------------------------------------------
echo ""
echo "--- Step 2: Deleting CloudFormation stack ---"
aws cloudformation delete-stack --stack-name "ImageFlow-${ENVIRONMENT}" --region "$AWS_REGION" 2>/dev/null || true
aws cloudformation wait stack-delete-complete --stack-name "ImageFlow-${ENVIRONMENT}" --region "$AWS_REGION" 2>/dev/null || true
echo "CloudFormation stack deleted"

# ---------------------------------------------------------------------------
# Step 3: Destroy Terraform infrastructure
# ---------------------------------------------------------------------------
echo ""
echo "--- Step 3: Destroying Terraform infrastructure ---"
if [ -d "terraform/live/${ENVIRONMENT}" ]; then
  cd "terraform/live/${ENVIRONMENT}"
  terraform destroy -auto-approve 2>/dev/null || true
  cd "$PROJECT_DIR"
  echo "Terraform resources destroyed"
fi

# ---------------------------------------------------------------------------
# Step 4: Delete CloudWatch dashboards
# ---------------------------------------------------------------------------
echo ""
echo "--- Step 4: Removing CloudWatch dashboards ---"
aws cloudwatch delete-dashboards --dashboard-names "ImageFlow-${ENVIRONMENT}" 2>/dev/null || true
echo "Dashboards removed"

# ---------------------------------------------------------------------------
# Step 5: Delete CloudWatch log groups
# ---------------------------------------------------------------------------
echo ""
echo "--- Step 5: Removing CloudWatch log groups ---"
LOG_GROUPS=(
  "/aws/lambda/ImageFlow-ImageProcessor-${ENVIRONMENT}"
  "/aws/lambda/ImageFlow-ImageAPI-${ENVIRONMENT}"
  "/aws/api-gateway/ImageFlow"
)
for lg in "${LOG_GROUPS[@]}"; do
  aws logs delete-log-group --log-group-name "$lg" 2>/dev/null || true
  echo "  Removed: $lg"
done

# ---------------------------------------------------------------------------
# Step 6: Delete local Lambda packages
# ---------------------------------------------------------------------------
echo ""
echo "--- Step 6: Cleaning local build artifacts ---"
rm -f "$PROJECT_DIR/processor.zip" "$PROJECT_DIR/api.zip" 2>/dev/null || true
echo "Removed local zip files"

# ---------------------------------------------------------------------------
# Step 7: Delete DynamoDB table
# ---------------------------------------------------------------------------
echo ""
echo "--- Step 7: Deleting DynamoDB table ---"
aws dynamodb delete-table --table-name "ImageFlow-Metadata-${ENVIRONMENT}" --region "$AWS_REGION" 2>/dev/null || true
echo "DynamoDB table deleted"

echo ""
echo "=== Cleanup complete! ==="
