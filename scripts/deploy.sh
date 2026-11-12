#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Serverless ImageFlow - Deploy Script
# =============================================================================
# Usage:
#   ./scripts/deploy.sh [--terraform | --cloudformation] [dev|prod]
#
# Prerequisites:
#   - AWS CLI configured with appropriate credentials
#   - Terraform 1.7+ installed (for --terraform mode)
#   - Python 3.12 with pip installed
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

ENVIRONMENT="${2:-dev}"
DEPLOY_MODE="${1:---terraform}"
AWS_REGION="${AWS_REGION:-us-east-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

LAMBDA_ARTIFACT_BUCKET="imageflow-${ENVIRONMENT}-lambda-artifacts-${ACCOUNT_ID}"
PROCESSOR_ZIP="processor.zip"
API_ZIP="api.zip"

echo "=== Serverless ImageFlow Deploy ==="
echo "Environment: $ENVIRONMENT"
echo "Mode:        $DEPLOY_MODE"
echo "Region:      $AWS_REGION"
echo "Account:     $ACCOUNT_ID"

# ---------------------------------------------------------------------------
# Step 1: Create artifact bucket if needed
# ---------------------------------------------------------------------------
echo ""
echo "--- Step 1: Lambda artifact bucket ---"
aws s3 ls "s3://${LAMBDA_ARTIFACT_BUCKET}" 2>/dev/null || {
  aws s3 mb "s3://${LAMBDA_ARTIFACT_BUCKET}" --region "$AWS_REGION"
  echo "Created bucket: $LAMBDA_ARTIFACT_BUCKET"
}

# ---------------------------------------------------------------------------
# Step 2: Package Lambda functions
# ---------------------------------------------------------------------------
echo ""
echo "--- Step 2: Packaging Lambda functions ---"

echo "Packaging image-processor..."
rm -rf /tmp/imageflow-processor /tmp/processor.zip
mkdir -p /tmp/imageflow-processor
pip install -r "$PROJECT_DIR/lambda/image-processor/requirements.txt" -t /tmp/imageflow-processor/ --quiet
cp "$PROJECT_DIR/lambda/image-processor/"*.py /tmp/imageflow-processor/
cd /tmp/imageflow-processor && zip -r9 "$PROJECT_DIR/$PROCESSOR_ZIP" . > /dev/null && cd "$PROJECT_DIR"
echo "  -> $PROCESSOR_ZIP ($(du -h "$PROCESSOR_ZIP" | cut -f1))"

echo "Packaging image-api..."
rm -rf /tmp/imageflow-api /tmp/api.zip
mkdir -p /tmp/imageflow-api
pip install -r "$PROJECT_DIR/lambda/image-api/requirements.txt" -t /tmp/imageflow-api/ --quiet
cp "$PROJECT_DIR/lambda/image-api/"*.py /tmp/imageflow-api/
cd /tmp/imageflow-api && zip -r9 "$PROJECT_DIR/$API_ZIP" . > /dev/null && cd "$PROJECT_DIR"
echo "  -> $API_ZIP ($(du -h "$API_ZIP" | cut -f1))"

# ---------------------------------------------------------------------------
# Step 3: Upload Lambda packages to S3
# ---------------------------------------------------------------------------
echo ""
echo "--- Step 3: Uploading Lambda packages ---"
aws s3 cp "$PROJECT_DIR/$PROCESSOR_ZIP" "s3://${LAMBDA_ARTIFACT_BUCKET}/processor.zip"
aws s3 cp "$PROJECT_DIR/$API_ZIP" "s3://${LAMBDA_ARTIFACT_BUCKET}/api.zip"
echo "Uploaded Lambda packages"

# ---------------------------------------------------------------------------
# Step 4: Deploy infrastructure
# ---------------------------------------------------------------------------
if [ "$DEPLOY_MODE" = "--terraform" ]; then
  echo ""
  echo "--- Step 4: Deploying with Terraform ---"
  cd "$PROJECT_DIR/terraform/live/$ENVIRONMENT"

  terraform init
  terraform apply -auto-approve \
    -var="processor_package_path=s3://${LAMBDA_ARTIFACT_BUCKET}/processor.zip" \
    -var="api_package_path=s3://${LAMBDA_ARTIFACT_BUCKET}/api.zip"

  cd "$PROJECT_DIR"

elif [ "$DEPLOY_MODE" = "--cloudformation" ]; then
  echo ""
  echo "--- Step 4: Deploying with CloudFormation ---"
  aws cloudformation deploy \
    --stack-name "ImageFlow-${ENVIRONMENT}" \
    --template-file "$PROJECT_DIR/cloudformation/main.yaml" \
    --parameter-overrides \
      Environment="$ENVIRONMENT" \
      CognitoDomain="imageflow-${ENVIRONMENT}-${ACCOUNT_ID}" \
      LambdaArtifactBucket="${LAMBDA_ARTIFACT_BUCKET}" \
      ProcessorPackagePath="processor.zip" \
      ApiPackagePath="api.zip" \
    --capabilities CAPABILITY_IAM \
    --region "$AWS_REGION"

fi

# ---------------------------------------------------------------------------
# Step 5: Deploy frontend to S3
# ---------------------------------------------------------------------------
echo ""
echo "--- Step 5: Deploying frontend ---"
FRONTEND_BUCKET="imageflow-${ENVIRONMENT}-frontend"
aws s3 sync "$PROJECT_DIR/frontend/" "s3://${FRONTEND_BUCKET}/" \
  --exclude "node_modules/*" --exclude ".git/*"

# ---------------------------------------------------------------------------
# Step 6: Invalidate CloudFront
# ---------------------------------------------------------------------------
echo ""
echo "--- Step 6: CloudFront invalidation ---"
CF_DIST_ID=$(aws cloudfront list-distributions \
  --query "DistributionList.Items[?contains(Origins.Items[0].DomainName, '${FRONTEND_BUCKET}')].Id" \
  --output text)
if [ -n "$CF_DIST_ID" ] && [ "$CF_DIST_ID" != "None" ]; then
  aws cloudfront create-invalidation --distribution-id "$CF_DIST_ID" --paths "/*" --no-cli-pager
  echo "CloudFront invalidation triggered for $CF_DIST_ID"
fi

# ---------------------------------------------------------------------------
# Step 7: Seed sample data
# ---------------------------------------------------------------------------
echo ""
echo "--- Step 7: Seeding sample data ---"
"$SCRIPT_DIR/seed-sample-images.sh" "$ENVIRONMENT" || true

echo ""
echo "=== Deploy complete! ==="
echo "Uploads bucket:    imageflow-${ENVIRONMENT}-uploads"
echo "Frontend bucket:   ${FRONTEND_BUCKET}"
echo "Metadata table:    ImageFlow-Metadata-${ENVIRONMENT}"
echo ""
echo "Next steps:"
echo "  1. Upload images via the frontend or S3 CLI"
echo "  2. Check the CloudWatch dashboard for metrics"
echo "  3. Run ./scripts/generate-load.sh for load testing"
