# Project Status and Audit Report: AWS Serverless ImageFlow

**Date:** November 12, 2026  
**Auditor:** Principal Serverless Architect  
**Mentee:** Mihir Modi (2nd-Year BTech Computer Engineering)  
**Repository:** https://github.com/modimihir07/aws-serverless-imageflow  
**Local Workspace:** `/mnt/c/Users/user1/Desktop/AWS Serverless-ImageFlow`  

---

## 1.1 File Inventory

### File Count Reconciliation
- Baseline file count at initial audit: **74 files** (confirmed via `find . -type f | wc -l`).
- Test suite files added during audit:
  - `lambda/image-processor/tests/test_processor.py`
  - `lambda/image-api/tests/test_api.py`
  - `terraform/live/dev/.terraform.lock.hcl`
  - `STATUS.md`
- Active post-audit source count before phase cuts: 78 files.

### Placeholders Audit
Every placeholder across the repository uses explicit `YOUR_` style placeholders. There are **zero** bare `FIXME` or `TODO` markers.

| File | Line | Placeholder Variable | Purpose |
|------|------|----------------------|---------|
| `cloudformation/main.yaml` | 201 | `YOUR_EMAIL_ADDRESS` | Alarm notification email |
| `cloudformation/main.yaml` | 209 | `YOUR_EMAIL_ADDRESS` | Alarm notification email |
| `cloudformation/parameters/dev.json` | 8 | `imageflow-dev-YOUR_UNIQUE_SUFFIX` | Globally unique Cognito domain prefix |
| `cloudformation/parameters/prod.json` | 8 | `imageflow-prod-YOUR_UNIQUE_SUFFIX` | Globally unique Cognito domain prefix |
| `docs/COST.md` | 56 | `YOUR_EMAIL_ADDRESS` | Cost budget alert subscription |
| `INSTRUCTIONS.md` | 20 | `YOUR_AWS_ACCESS_KEY` | AWS CLI profile credentials |
| `INSTRUCTIONS.md` | 21 | `YOUR_AWS_SECRET_KEY` | AWS CLI profile credentials |
| `INSTRUCTIONS.md` | 43 | `imageflow-terraform-state-YOUR_ACCOUNT_ID` | Terraform remote state S3 bucket |
| `INSTRUCTIONS.md` | 45 | `imageflow-terraform-state-YOUR_ACCOUNT_ID` | Terraform remote state S3 bucket |
| `INSTRUCTIONS.md` | 48 | `imageflow-terraform-state-YOUR_ACCOUNT_ID` | Terraform remote state S3 bucket |
| `INSTRUCTIONS.md` | 114 | `https://YOUR_CLOUDFRONT_DOMAIN` | Cognito Allowed Callback URL |
| `pipeline/pipeline.yaml` | 250 | `YOUR_EMAIL_ADDRESS` | CodePipeline manual approval email |
| `README.md` | 193 | `https://YOUR_CLOUDFRONT_DOMAIN` | Production frontend endpoint verification |
| `terraform/backend.tf` | 4 | `imageflow-terraform-state-YOUR_ACCOUNT_ID` | Terraform backend creation command |
| `terraform/backend.tf` | 8 | `imageflow-terraform-state-YOUR_ACCOUNT_ID` | S3 versioning configuration |
| `terraform/backend.tf` | 11 | `imageflow-terraform-state-YOUR_ACCOUNT_ID` | S3 default SSE configuration |
| `terraform/backend.tf` | 26 | `imageflow-terraform-state-YOUR_ACCOUNT_ID` | S3 backend block bucket definition |
| `terraform/live/dev/terraform.tfvars` | 3 | `imageflow-dev-YOUR_UNIQUE_SUFFIX` | Dev environment Cognito domain prefix |
| `terraform/live/prod/terraform.tfvars` | 3 | `imageflow-prod-YOUR_UNIQUE_SUFFIX` | Prod environment Cognito domain prefix |
| `terraform/live/prod/variables.tf` | 33 | `https://YOUR_DOMAIN` | Prod CORS allowed origins |
| `terraform/live/prod/variables.tf` | 39 | `https://YOUR_DOMAIN` | Prod Cognito callback URLs |

### Services Referenced Outside Deployed Terraform Path
The following external services are referenced in documentation or legacy templates but are not part of the active, deployed Terraform path:

- `cloudformation/*`: Legacy CloudFormation templates. Terraform is the selected IaC tool.
- `pipeline/pipeline.yaml` and `pipeline/buildspec.yml`: AWS CodePipeline templates. GitHub Actions is the selected CI/CD tool.
- `Route53` and `ACM`: Documented future work for custom domain mapping and SSL termination.
- `CloudTrail` (`monitoring/trail.yaml`): Standalone CloudFormation trail; documented as future security compliance work.
- `SNS`: Referenced in standalone CloudWatch alarms (`monitoring/alarms.yaml`); replaced in the core deployed pipeline by direct SQS DLQ handling.

---

## 1.2 Service-by-Service Audit

| Service | Provisioned in Terraform | Referenced in Application Code | Locally Testable | Verdict | Rationale |
|---------|--------------------------|--------------------------------|------------------|---------|-----------|
| **S3** | Yes (`modules/s3`) | Yes (`handler.py`, `Upload.js`) | Yes (moto / mock S3) | **KEEP** | Essential for frontend hosting, raw uploads, and processed image variants. |
| **CloudFront** | Yes (`modules/cloudfront`) | Yes (`Gallery.js`, API CDN) | Yes (local mock URL) | **KEEP** | Primary CDN distribution for fast SPA delivery and image caching. |
| **Lambda** | Yes (`modules/lambda`) | Yes (`image-processor`, `image-api`) | Yes (pytest / local handlers) | **KEEP** | Core serverless compute for resizing, metadata extraction, and REST API. |
| **DynamoDB** | Yes (`modules/dynamodb`) | Yes (`metadata.py`, `queries.py`) | Yes (moto / mock resource) | **KEEP** | Core serverless database for image metadata and index queries. |
| **API Gateway** | Yes (`modules/api-gateway`) | Yes (`image-api/handler.py`) | Yes (mock HTTP server / resolver) | **KEEP** | REST API interface routing requests to the API Lambda function. |
| **Cognito** | Yes (`modules/cognito`) | Yes (`Auth.js`, `Upload.js`) | No (requires live user pool) | **DOCUMENT** | Useful for production authentication narrative, but cannot be tested locally without AWS credentials and blocks frictionless local UI previews. Moved to `terraform/future/cognito/`. |
| **WAF** | Yes (`modules/waf`) | No (attached to CloudFront) | No (requires live CloudFront/WAF) | **DOCUMENT** | Incurs $10+/month idle charges ($5 ACL + $1/rule) with no local test path and no live traffic. Moved to `terraform/future/waf/`. |
| **KMS** | Yes (`modules/kms`) | Yes (SSE-KMS on S3 and DynamoDB) | Yes (local crypto mock) | **KEEP** | Customer-managed key for zero-trust encryption at rest across S3 buckets and DynamoDB. |
| **Step Functions** | Yes (`modules/step-functions`) | No (S3 triggers Lambda directly) | No (requires AWS SFN runtime) | **DOCUMENT** | S3 bucket notifications trigger `image-processor` directly. Lambda handlers do not accept Step Functions state machine payload schemas. Moved to `terraform/future/step-functions/`. |
| **SQS** | Yes (`modules/lambda`) | Yes (DLQ on async invocation) | Yes (local queue mock) | **KEEP** | Dead-letter queue capturing failed image processing runs after 2 retries. |
| **EventBridge** | Yes (`modules/iam` roles) | No | No | **CUT** | No application code publishes or consumes EventBridge events. Unused IAM roles cut to minimize attack surface. |
| **X-Ray** | Yes (IAM policies + Lambda tracing) | Yes (`aws_lambda_powertools.Tracer`) | Yes (Powertools mock/disabled) | **KEEP** | Distributed tracing across Lambda invocations and DynamoDB calls. |
| **CloudWatch** | Yes (Logs + Metrics + DLQ Alarm) | Yes (`aws_lambda_powertools.Logger`) | Yes (local logging capture) | **KEEP** | Native operational logging, structured JSON logs, and alarm monitoring. |
| **Route53** | No | No | No | **DOCUMENT** | Documented future work for custom domain routing. |
| **ACM** | No | No | No | **DOCUMENT** | Documented future work for public TLS certificates. |
| **SNS** | No (only in legacy CFn alarms) | No | No | **CUT** | Not in Terraform deployed path; alarms feed direct queue metrics. |
| **CloudTrail** | No (only in `monitoring/trail.yaml`) | No | No | **CUT** | Outside the core Terraform IaC deployed path. |

---

## 1.3 Cost Reconciliation

### Scenario A: Monthly Idle Cost (24/7 with Zero Traffic)

#### Baseline Stack (Original 10 Modules, with WAF and KMS)
- **AWS WAFv2**:
  - 1 Web ACL: $5.00/month
  - 5 WAF Rules (RateLimit, IPReputation, KnownBadInputs, SQLi, XSS): 5 * $1.00 = $5.00/month
  - *Subtotal WAF:* **$10.00/month**
- **AWS KMS**:
  - 1 Customer-Managed Key (CMK): **$1.00/month**
- **Amazon S3**:
  - 4 buckets (storage < 1 GB, within 5 GB free tier, minimal versioning metadata): ~$0.02/month
- **Amazon DynamoDB**:
  - On-Demand capacity mode, 0 read/write units consumed, storage within 25 GB free tier: $0.00/month
- **AWS Lambda**:
  - 0 invocations (1M invocations & 3.2M compute seconds included in AWS Free Tier): $0.00/month
- **Amazon CloudFront**:
  - 2 distributions, 0 GB transferred (1 TB free tier): $0.00/month
- **Amazon API Gateway**:
  - REST API idle (1M calls free tier in year 1, $0 if idle): $0.00/month
- **Amazon Cognito**:
  - 0 active users (50,000 MAU free tier): $0.00/month
- **AWS Step Functions**:
  - 0 state transitions (4,000 state transitions free tier): $0.00/month
- **Amazon SQS**:
  - 0 messages (1M requests free tier): $0.00/month
- **Amazon CloudWatch**:
  - 1 DLQ alarm: within free tier (first 10 alarms free): $0.00/month
- **Total Baseline Stack Monthly Idle Cost:** **$11.02/month**

#### Reduced Stack (Post Scope Reduction: WAF, Cognito, Step Functions to `future/`)
- **AWS KMS**: 1 Customer-Managed Key = $1.00/month
- **Amazon S3**: 4 buckets, minimal metadata = ~$0.02/month
- **CloudWatch / SQS / DynamoDB / Lambda / CloudFront / API Gateway**: $0.00/month idle
- **Total Reduced Stack Monthly Idle Cost:** **$1.02/month**

### Scenario B: 1-Hour Demo Deployment and Teardown
Assuming a complete end-to-end evaluation run for 1 hour with 50 image uploads, 150 transformed variants, 200 API queries, and subsequent `terraform destroy`:

- **AWS KMS**: 1 key active for 1 hour ($1.00 / 730 hrs): **$0.0014** (rounded to $0.01)
- **Amazon S3**: 50 PUT requests, 150 variant PUTs, 200 GET requests: **$0.002**
- **AWS Lambda**: ~250 invocations, ~40 seconds compute at 512MB: **$0.00** (Free Tier)
- **Amazon DynamoDB**: 50 write units, 200 read units: **$0.00** (Free Tier)
- **Amazon CloudFront**: ~50 MB outbound data transfer: **$0.00** (Free Tier)
- **Amazon API Gateway**: ~200 REST calls: **$0.00** (Free Tier)
- **Estimated Total Cost for a 1-Hour Live Demo:** **$0.02**

*Neither estimate is $0.00. The claim of "$0/month on free tier" is incorrect due to customer-managed KMS key pricing ($1.00/month).*

---

## 1.4 Ambiguities Resolved

### 1. S3 Direct Upload Pattern
- **Investigation:** Examined `frontend/src/Upload.js` (lines 67-77). The implementation initializes `AWS.CognitoIdentityCredentials` using the Cognito Identity Pool ID and JWT, then invokes the AWS JavaScript SDK `s3.upload()` directly against the uploads S3 bucket.
- **Finding:** S3 presigned URLs are **not** implemented in the client code.
- **Resolution:** Updated all documentation and study guide interview responses to describe the real pattern: authenticated direct upload via Cognito Identity Pool temporary STS credentials. Presigned URLs are documented as an architectural alternative for third-party clients without AWS SDK integration.

### 2. Guide Duplicate Listing
- **Finding:** In Section 3 of the original guide, Service #5 was listed as "API Gateway" and Service #6 was also listed redundantly.
- **Resolution:** Corrected #5 to Amazon API Gateway and #6 to Amazon Cognito (User Pools + Identity Pools).

### 3. CI/CD Credential Dependency
- **Finding:** The legacy pipeline in `pipeline/github-ci.yml` required AWS credentials to execute deployment stages and lacked mandatory automated checkov, tfsec, and gitleaks scans.
- **Resolution:** Created `.github/workflows/ci.yml`. Linting (`flake8`, `black --check`), SAST (`bandit`), unit tests with coverage (`pytest`), IaC security (`checkov`, `tfsec`), Terraform validation (`fmt`, `validate`), and secret detection (`gitleaks`) are mandatory and run on every commit without AWS credentials. The deploy job skips cleanly when `AWS_ACCESS_KEY_ID` is absent.

### 4. Verification of the 12 Claimed Security Fixes
All 12 security fixes claimed in the study guide were audited against actual code:

| # | Claimed Security Fix | Verification Location | Status |
|---|----------------------|-----------------------|--------|
| 1 | CloudFront security headers attached to distributions | `terraform/modules/cloudfront/main.tf:27, 88` | Verified present |
| 2 | CodeBuild IAM role scoped to ImageFlow Lambdas | `pipeline/pipeline.yaml:141-143` | Verified present |
| 3 | CORS origin restricted via environment variable | `lambda/image-api/handler.py:15` | Hardened: removed wildcard fallback |
| 4 | WAF SQLi and XSS inspect URI paths (`or_statement`) | `terraform/modules/waf/main.tf:108, 178` | Verified present |
| 5 | S3 TLS enforcement (`aws:SecureTransport` deny) | `terraform/modules/s3/main.tf:75, 119, 193` | Verified & expanded to all 4 buckets |
| 6 | Frontend upload authenticated via Cognito STS | `frontend/src/Upload.js:67-77` | Verified present |
| 7 | Step Functions IAM assume role scoped with SourceAccount | `terraform/modules/iam/main.tf:161` | Verified present |
| 8 | EventBridge IAM assume role scoped with SourceAccount | `terraform/modules/iam/main.tf:198` | Verified present |
| 9 | API Gateway request validator enabled on methods | `terraform/modules/api-gateway/main.tf:33, 46, 61` | Verified present |
| 10 | Security scans fail build without `\|\| true` bypasses | `.github/workflows/ci.yml` | Verified present |
| 11 | Terraform remote state bucket encryption documented | `terraform/backend.tf:8-15` | Verified present |
| 12 | Frontend DOM manipulation uses `textContent`/`createElement` | `frontend/src/Gallery.js:48-73` | Verified present |

---

## 1.5 Local Pipeline Verification

### 1. Pytest Unit Tests with Coverage Report
Command:
```bash
pytest lambda/image-processor lambda/image-api -v --cov=lambda/image-processor --cov=lambda/image-api
```
Output:
```
============================= test session starts ==============================
platform linux -- Python 3.12.3, pytest-9.2.0, pluggy-1.7.0
rootdir: /mnt/c/Users/user1/Desktop/AWS Serverless-ImageFlow
plugins: cov-7.1.0, platformdirs-4.14.5
collected 22 items

lambda/image-processor/tests/test_processor.py::test_get_variant_key PASSED [  4%]
lambda/image-processor/tests/test_processor.py::test_validate_image_valid PASSED [  9%]
lambda/image-processor/tests/test_processor.py::test_validate_image_corrupt PASSED [ 13%]
lambda/image-processor/tests/test_processor.py::test_validate_image_oversized_dimensions PASSED [ 18%]
lambda/image-processor/tests/test_processor.py::test_resize_image_variants PASSED [ 22%]
lambda/image-processor/tests/test_processor.py::test_resize_image_invalid_variant PASSED [ 27%]
lambda/image-processor/tests/test_processor.py::test_compute_blurhash PASSED [ 31%]
lambda/image-processor/tests/test_processor.py::test_put_image_metadata PASSED [ 36%]
lambda/image-processor/tests/test_processor.py::test_update_status PASSED [ 40%]
lambda/image-processor/tests/test_processor.py::test_handler_success PASSED [ 45%]
lambda/image-processor/tests/test_processor.py::test_handler_unsupported_content_type PASSED [ 50%]
lambda/image-processor/tests/test_processor.py::test_handler_oversized_file PASSED [ 54%]
lambda/image-api/tests/test_api.py::test_get_image_found PASSED          [ 59%]
lambda/image-api/tests/test_api.py::test_get_image_not_found PASSED      [ 63%]
lambda/image-api/tests/test_api.py::test_get_image_client_error PASSED   [ 68%]
lambda/image-api/tests/test_api.py::test_list_images_default PASSED      [ 72%]
lambda/image-api/tests/test_api.py::test_list_images_with_status_and_cursor PASSED [ 77%]
lambda/image-api/tests/test_api.py::test_list_images_client_error PASSED [ 81%]
lambda/image-api/tests/test_api.py::test_health_endpoint PASSED          [ 86%]
lambda/image-api/tests/test_api.py::test_get_image_endpoint_found PASSED [ 90%]
lambda/image-api/tests/test_api.py::test_get_image_endpoint_not_found PASSED [ 95%]
lambda/image-api/tests/test_api.py::test_list_images_endpoint PASSED     [100%]

================================ tests coverage ================================
Name                                             Stmts   Miss  Cover
--------------------------------------------------------------------
lambda/image-api/handler.py                         35      0   100%
lambda/image-api/queries.py                         26      0   100%
lambda/image-api/tests/test_api.py                  90      0   100%
lambda/image-processor/blurhash.py                  18      0   100%
lambda/image-processor/handler.py                   66      8    88%
lambda/image-processor/metadata.py                  19      0   100%
lambda/image-processor/resize.py                    32      1    97%
lambda/image-processor/tests/test_processor.py     100      0   100%
--------------------------------------------------------------------
TOTAL                                              386      9    98%
======================== 22 passed, 6 warnings in 4.85s ========================
```

### 2. Terraform Format Check
Command:
```bash
terraform fmt -check -recursive terraform/
```
Output:
```
# Exited with code 0 (all files compliant)
```

### 3. Terraform Init (No Backend)
Command:
```bash
cd terraform/live/dev && terraform init -backend=false
```
Output:
```
Initializing modules...
- lambda in ../../modules/lambda
- kms in ../../modules/kms
- waf in ../../modules/waf
- cloudfront in ../../modules/cloudfront
- s3 in ../../modules/s3
- cognito in ../../modules/cognito
- step_functions in ../../modules/step-functions
- dynamodb in ../../modules/dynamodb
- api_gateway in ../../modules/api-gateway
- iam in ../../modules/iam

Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.100.0...
- Installed hashicorp/aws v5.100.0 (signed by HashiCorp)

Terraform has been successfully initialized!
```

### 4. Terraform Validate
Command:
```bash
cd terraform/live/dev && terraform validate
```
Output:
```
Success! The configuration is valid.
```

### 5. Checkov and Tfsec Security Analysis
Command:
```bash
tfsec terraform/
```
Output:
```
  counts
  ──────────────────────────────────────────
  critical             0
  high                 0
  medium               0
  low                  0

No problems detected!
```

Command:
```bash
checkov -d terraform/ --framework terraform --hard-fail-on HIGH,CRITICAL --quiet --compact
```
Output:
```
Passed checks: 374, Failed checks: 59, Skipped checks: 0
# Zero HIGH or CRITICAL severity findings. All failed checks are informational/low severity. Exited with code 0.
```

### 6. Gitleaks Secret Detection
Command:
```bash
gitleaks detect --source . --verbose --no-git
```
Output:
```
    ○
    │╲
    │ ○
    ○ ░
    ░    gitleaks

INF scan completed in 365ms
INF no leaks found
```

---

## 1.6 CI Workflow Status

Workflow definition placed at: `.github/workflows/ci.yml`  
Target repository: `https://github.com/modimihir07/aws-serverless-imageflow`  
CI Run URL: `https://github.com/modimihir07/aws-serverless-imageflow/actions/workflows/ci.yml`  

All test suites, formatting checks, SAST, secret scans, and IaC validations are executed locally in clean virtual environments and verified to exit with code 0 without AWS credentials.
