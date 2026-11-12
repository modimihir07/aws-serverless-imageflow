# AWS Serverless ImageFlow - Deployment Instructions

> **Made by Mihir Modi** - BTech Computer Engineering, Gujarat

## Prerequisites

| Tool | Version | Check Command |
|------|---------|---------------|
| AWS CLI | v2+ | `aws --version` |
| Terraform | 1.7+ | `terraform --version` |
| Python | 3.12 | `python3 --version` |
| Node.js | 20+ (optional, for frontend dev) | `node --version` |
| pip | 23+ | `pip --version` |

## Step 1: AWS Account Setup

```bash
# Configure AWS CLI
aws configure
# AWS Access Key ID: YOUR_AWS_ACCESS_KEY
# AWS Secret Access Key: YOUR_AWS_SECRET_KEY
# Default region: us-east-1
# Default output format: json

# Verify identity
aws sts get-caller-identity
```

## Step 2: Clone & Project Setup

```bash
# Navigate to project
cd ~/Desktop/Serverless-ImageFlow

# Make scripts executable
chmod +x scripts/*.sh
```

## Step 3: Create Terraform Backend (S3 + DynamoDB)

```bash
# Create S3 bucket for Terraform state (with encryption)
aws s3 mb s3://imageflow-terraform-state-YOUR_ACCOUNT_ID --region us-east-1
aws s3api put-bucket-encryption \
  --bucket imageflow-terraform-state-YOUR_ACCOUNT_ID \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-bucket-versioning \
  --bucket imageflow-terraform-state-YOUR_ACCOUNT_ID \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name imageflow-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

Then uncomment the `backend "s3"` block in `terraform/backend.tf` and copy it to the `live/dev/` and `live/prod/` directories.

## Step 4: Deploy Infrastructure

### Option A: Terraform (Recommended)

```bash
# Deploy dev environment
./scripts/deploy.sh --terraform dev
```

### Option B: CloudFormation

```bash
# Package Lambda code first
pip install -r lambda/image-processor/requirements.txt -t /tmp/processor-deps/
cp lambda/image-processor/*.py /tmp/processor-deps/
cd /tmp/processor-deps && zip -r9 ~/Desktop/Serverless-ImageFlow/processor.zip . && cd -

pip install -r lambda/image-api/requirements.txt -t /tmp/api-deps/
cp lambda/image-api/*.py /tmp/api-deps/
cd /tmp/api-deps && zip -r9 ~/Desktop/Serverless-ImageFlow/api.zip . && cd -

# Create artifact bucket
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws s3 mb s3://imageflow-dev-lambda-artifacts-$ACCOUNT_ID

# Upload Lambda packages
aws s3 cp processor.zip s3://imageflow-dev-lambda-artifacts-$ACCOUNT_ID/
aws s3 cp api.zip s3://imageflow-dev-lambda-artifacts-$ACCOUNT_ID/

# Deploy CloudFormation
aws cloudformation deploy \
  --stack-name ImageFlow-dev \
  --template-file cloudformation/main.yaml \
  --parameter-overrides \
    Environment=dev \
    CognitoDomain=imageflow-dev-$ACCOUNT_ID \
    LambdaArtifactBucket=imageflow-dev-lambda-artifacts-$ACCOUNT_ID \
  --capabilities CAPABILITY_IAM
```

## Step 5: Deploy Frontend

```bash
# The deploy script does this automatically.
# Manual alternative:
aws s3 sync frontend/ s3://imageflow-dev-frontend/ --exclude "node_modules/*"
```

## Step 6: Configure Cognito

1. Go to **Cognito → User Pools → ImageFlow-UserPool-dev**
2. Under **App integration → App client settings**
3. Add callback URL: `https://YOUR_CLOUDFRONT_DOMAIN` (or `http://localhost:3000` for local)
4. Add sign-out URL: Same as callback
5. Under **Domain → Update the Cognito domain** if needed
6. Update `frontend/src/App.js` with the correct Cognito domain and app client ID

## Step 7: Seed Sample Images

```bash
# Downloads 10 sample images and uploads to S3
# This triggers the Lambda processing pipeline
./scripts/seed-sample-images.sh dev
```

## Step 8: Verify Deployment

```bash
# Check CloudFormation stack
aws cloudformation describe-stacks --stack-name ImageFlow-dev

# Check Lambda functions
aws lambda list-functions --query "Functions[?starts_with(FunctionName, 'ImageFlow')]"

# Check DynamoDB table
aws dynamodb describe-table --table-name ImageFlow-Metadata-dev

# Check S3 buckets
aws s3 ls | grep imageflow

# View Lambda logs
aws logs describe-log-groups --log-group-name-prefix /aws/lambda/ImageFlow
```

## Step 9: Monitor

```bash
# Open CloudWatch Dashboard
open "https://us-east-1.console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=ImageFlow-dev"

# View X-Ray traces
open "https://us-east-1.console.aws.amazon.com/xray/home?region=us-east-1#/service-map"
```

## Step 10: Local Development

```bash
# Test Lambda locally with SAM CLI
sam local invoke ImageProcessor -e scripts/test-event.json

# Run frontend locally
cd frontend && npm start
# Open: http://localhost:3000

# Run load test
./scripts/generate-load.sh dev 100 10
```

## Cleanup

```bash
# DESTROY EVERYTHING
./scripts/cleanup.sh dev
```

## Manual Steps Not Automated

1. **Cognito App Client URLs** - Update callback/logout URLs after CloudFront deployment
2. **Terraform Backend** - Uncomment backend config after creating S3 + DynamoDB
3. **Route53 Domain** - If using custom domain, create hosted zone and update CloudFront alternate domain
4. **ACM Certificate** - Request in us-east-1 for CloudFront, validate via DNS/email

## Troubleshooting

| Issue | Likely Cause | Solution |
|-------|-------------|----------|
| Lambda timeout | Image too large | Reduce image size or increase Lambda timeout/memory |
| S3 trigger not firing | Missing Lambda permission | Check S3 bucket notification config |
| API Gateway 401 | Invalid/expired token | Re-authenticate via Cognito Hosted UI |
| CloudFront 403 | OAC/OAI misconfigured | Check bucket policy allows CloudFront access |
| Terraform state lock | Previous failed apply | `terraform force-unlock <lock-id>` |
| "Access Denied" on upload | Incorrect Cognito creds | Check identity pool roles policy |
