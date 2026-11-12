**Status: not yet deployed to a live AWS account. These are the exact commands to deploy from scratch.**

---

# AWS Serverless ImageFlow - Deployment Guide

This guide provides reproduction steps to deploy AWS Serverless ImageFlow to a fresh AWS account.

---

## 1. Prerequisites

Before starting deployment, confirm you have access to an active AWS account and the required local toolchain:

### Required AWS Permissions
Your IAM user or role must possess sufficient administrative permissions to create and manage:
- AWS Lambda functions, execution roles, and event source mappings
- Amazon S3 buckets, bucket policies, and lifecycle configurations
- Amazon DynamoDB tables and indexes
- Amazon CloudFront distributions and Origin Access Control (OAC)
- Amazon API Gateway REST APIs and stage settings
- AWS KMS Customer-Managed Keys (CMK)
- Amazon SQS queues and CloudWatch alarms

### Required Tools and Versions
- **AWS CLI:** v2.15.0 or later (`aws --version`)
- **Terraform:** v1.7.0 or later (`terraform version`)
- **Python:** v3.12.x (`python3 --version`)
- **Node.js:** v18.x or later (optional, for local UI preview: `node --version`)
- **Zip utility:** standard CLI zip utility

---

## 2. AWS Setup

### Step 2.1: Retrieve Account ID and Configure AWS CLI
Run `aws sts get-caller-identity` to confirm CLI access and identify your target AWS account ID:

```bash
aws sts get-caller-identity
```

Export environment variables for your deployment session:

```bash
export AWS_REGION="us-east-1"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Targeting AWS Account ID: ${AWS_ACCOUNT_ID} in region ${AWS_REGION}"
```

### Step 2.2: Create Remote Terraform State Bucket and Lock Table (Optional)
If running Terraform with a remote S3 backend, provision the state bucket and enable encryption and versioning:

```bash
# Create state bucket
aws s3 mb s3://imageflow-terraform-state-${AWS_ACCOUNT_ID} --region ${AWS_REGION}

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket imageflow-terraform-state-${AWS_ACCOUNT_ID} \
  --versioning-configuration Status=Enabled

# Enable default server-side encryption
aws s3api put-bucket-encryption \
  --bucket imageflow-terraform-state-${AWS_ACCOUNT_ID} \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block all public access
aws s3api put-public-access-block \
  --bucket imageflow-terraform-state-${AWS_ACCOUNT_ID} \
  --public-access-block-configuration '{
    "BlockPublicAcls": true,
    "IgnorePublicAcls": true,
    "BlockPublicPolicy": true,
    "RestrictPublicBuckets": true
  }'
```

*Note: For a temporary evaluation or 1-hour demo, you can run Terraform using local state by skipping backend configuration.*

---

## 3. Package Lambda Functions and Deploy via Terraform

### Step 3.1: Package Lambda Functions
Terraform packages Lambda code from local zip archives. Package the two functions:

```bash
# Package image-processor
cd lambda/image-processor
mkdir -p dist
pip install -r requirements.txt -t dist/
cp *.py dist/
cd dist && zip -r9 ../dist/processor.zip . && cd ../../..

# Package image-api
cd lambda/image-api
mkdir -p dist
pip install -r requirements.txt -t dist/
cp *.py dist/
cd dist && zip -r9 ../dist/api.zip . && cd ../../..
```

### Step 3.2: Initialize and Apply Terraform
Navigate to the development environment configuration:

```bash
cd terraform/live/dev

# Initialize providers
terraform init

# Plan deployment
terraform plan -out=tfplan

# Apply configuration
terraform apply tfplan
```

Expected output:
```
Apply complete! Resources: 24 added, 0 changed, 0 destroyed.

Outputs:
api_gateway_url = "https://a1b2c3d4e5.execute-api.us-east-1.amazonaws.com/dev"
cloudfront_frontend_url = "https://d111111abcdef8.cloudfront.net"
cloudfront_images_url = "https://d222222abcdef8.cloudfront.net"
dynamodb_table = "ImageFlow-Metadata-dev"
uploads_bucket = "imageflow-dev-uploads-dev"
```

---

## 4. Post-Apply Verification

### Step 4.1: Retrieve Endpoint URLs
Capture the provisioned URLs from Terraform outputs:

```bash
export API_URL=$(terraform output -raw api_gateway_url)
export FRONTEND_URL=$(terraform output -raw cloudfront_frontend_url)
export UPLOADS_BUCKET=$(terraform output -raw uploads_bucket)

echo "Frontend: ${FRONTEND_URL}"
echo "API:      ${API_URL}"
echo "Uploads:  ${UPLOADS_BUCKET}"
```

### Step 4.2: Verify API Health Endpoint
Run an HTTP GET request against the API Gateway `/health` endpoint:

```bash
curl -i "${API_URL}/health"
```

Expected response:
```http
HTTP/2 200
content-type: application/json

{"status": "ok", "timestamp": "2026-11-12T06:00:00.000Z"}
```

---

## 5. End-to-End Pipeline Test

### Step 5.1: Upload a Test Image to S3
Upload a sample image to the raw uploads bucket:

```bash
# Create a test image using Python
python3 -c "
from PIL import Image
img = Image.new('RGB', (800, 600), color='forestgreen')
img.save('test-upload.jpg')
"

# Upload directly to the raw uploads S3 bucket
aws s3 cp test-upload.jpg s3://${UPLOADS_BUCKET}/photos/test-upload.jpg \
  --content-type "image/jpeg"
```

### Step 5.2: Verify Asynchronous Lambda Execution
Inspect CloudWatch logs for the `ImageFlow-ImageProcessor-dev` function:

```bash
aws logs filter-log-events \
  --log-group-name "/aws/lambda/ImageFlow-ImageProcessor-dev" \
  --filter-pattern "Completed"
```

### Step 5.3: Verify Metadata in DynamoDB
Query the DynamoDB table to verify that image metadata and blurhash were recorded:

```bash
aws dynamodb scan \
  --table-name ImageFlow-Metadata-dev \
  --query "Items[*].[image_id.S, original_key.S, status.S, blurhash.S]" \
  --output table
```

### Step 5.4: Verify Images on CloudFront
Query the API Gateway `/images` endpoint and fetch one of the generated thumbnail variants through the CloudFront images distribution:

```bash
curl -s "${API_URL}/images" | jq .
```

---

## 6. Teardown

To avoid incurring ongoing cloud costs, destroy all provisioned infrastructure when testing is finished:

```bash
cd terraform/live/dev

# Empty S3 buckets first (Terraform cannot delete non-empty buckets)
aws s3 rm s3://${UPLOADS_BUCKET} --recursive
PROCESSED_BUCKET=$(aws s3 ls | grep imageflow-dev-processed | awk '{print $3}')
FRONTEND_BUCKET=$(aws s3 ls | grep imageflow-dev-frontend | awk '{print $3}')
LOGS_BUCKET=$(aws s3 ls | grep imageflow-dev-logs | awk '{print $3}')

aws s3 rm s3://${PROCESSED_BUCKET} --recursive || true
aws s3 rm s3://${FRONTEND_BUCKET} --recursive || true
aws s3 rm s3://${LOGS_BUCKET} --recursive || true

# Run Terraform destroy
terraform destroy -auto-approve
```

Expected output:
```
Destroy complete! Resources: 24 destroyed.
```

---

## 7. Known First-Deploy Pitfalls

When executing a first-time deployment to a live AWS account, expect the following platform behaviors:

1. **CloudFront Propagation Latency (~15 minutes):**  
   Newly created CloudFront distributions require approximately 5 to 15 minutes to deploy to all global edge locations. Accessing the frontend URL immediately after `terraform apply` may return a DNS resolution error or HTTP 504.
2. **API Gateway Stage Deployment Delay (30 to 60 seconds):**  
   Changes to REST API method definitions and deployment stages take up to 60 seconds to propagate to Regional API Gateway execution endpoints.
3. **Lambda Cold Start on First Invocation (2 to 3 seconds):**  
   The initial invocation of `image-processor` or `image-api` incurs a cold start while AWS initializes the microVM, runtime container, and imports libraries (Pillow, boto3, Powertools). Subsequent warm invocations execute in under 300ms.
4. **IAM Role Propagation Delay (~10 seconds):**  
   AWS IAM is an eventually consistent global service. Newly created Lambda execution roles may take 5 to 10 seconds to propagate across all STS regional endpoints. In rare instances, first-call invocations triggered immediately after role creation may fail with an `AccessDenied` error before succeeding on automatic retry.

---

## 8. Estimated Deployment Cost Breakdown

Running this complete stack for a **1-hour live demonstration** and subsequently destroying it incurs the following estimated charges:

| Service | Activity during 1-Hour Demo | Estimated Cost |
|---------|-----------------------------|----------------|
| **AWS KMS** | 1 Customer-Managed Key active for 1 hour ($1.00 / 730 hrs) | $0.0014 (billed as ~$0.01) |
| **Amazon S3** | ~50 PUT requests, ~150 GET requests, < 100 MB storage | $0.002 |
| **AWS Lambda** | ~200 invocations, ~40 seconds execution at 512MB RAM | $0.000 (within Free Tier) |
| **Amazon DynamoDB** | ~50 write units, ~200 read units | $0.000 (within Free Tier) |
| **Amazon CloudFront** | ~100 MB data transfer out across edge locations | $0.000 (within 1 TB Free Tier) |
| **Amazon API Gateway** | ~200 REST API calls | $0.000 (within Free Tier) |
| **Total Estimated 1-Hour Demo Cost** | | **~$0.02** |

*All resources should be destroyed using `terraform destroy` immediately following validation to prevent unexpected baseline costs.*
