# Static Security Audit Report: AWS Serverless ImageFlow

**Date:** November 12, 2026  
**Auditor:** Principal Serverless Architect  
**Scope:** Static Code & Infrastructure Analysis (IaC, Lambda Runtimes, S3, IAM, CloudFront, API Gateway)  
**Classification:** Internal Portfolio Architecture Review  

---

## 1. Executive Summary

This security audit conducted a code-level review across the entire AWS Serverless ImageFlow repository. The audit evaluated Infrastructure as Code (Terraform), Lambda Python handlers, API Gateway configurations, CloudFront distributions, S3 storage policies, and IAM role scopes.

The analysis validated that all 12 security issues remediated in the original architecture remain intact. Additionally, this audit identified and remediated 4 new security vulnerabilities (insecure CORS wildcard fallback, S3 frontend public access and TLS policy gaps, and Lambda idempotency replay vulnerabilities).

---

## 2. Audited Security Findings & Remediations

| # | Severity | Category | Issue | File & Line | Remediated Fix |
|---|----------|----------|-------|-------------|----------------|
| 1 | HIGH | CDN / Transport | CloudFront security response headers policy defined but previously unattached | `terraform/modules/cloudfront/main.tf:27, 88` | Attached `response_headers_policy_id` to both frontend and image distribution cache behaviors. Enforces HSTS (31536000s), `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, and `Strict-Transport-Security`. |
| 2 | HIGH | CI/CD IAM | Build pipeline role previously granted unrestricted `Resource: "*"` for Lambda updates | `pipeline/pipeline.yaml:141-143` | Scoped CodeBuild IAM execution role to only ImageFlow Lambda ARNs (`arn:aws:lambda:...:function:ImageFlow-*`). (Module now retired in favor of GitHub Actions with OIDC). |
| 3 | MEDIUM | API Security | Insecure fallback to wildcard CORS (`allow_origin: "*"`) when `ALLOWED_ORIGINS` unset | `lambda/image-api/handler.py:15` | Removed wildcard fallback. Defaulted to configured origin domain `https://localhost:3000` (or CloudFront origin) with explicit header allowlist (`Content-Type`, `Authorization`). |
| 4 | MEDIUM | Storage / Public Access | Frontend S3 bucket had `restrict_public_buckets = false` and lacked TLS enforcement policy | `terraform/modules/s3/main.tf:143-165` | Enabled `restrict_public_buckets = true` on frontend bucket. Added explicit bucket policy statement denying all non-TLS requests (`aws:SecureTransport = false`). |
| 5 | MEDIUM | Storage / Cryptography | Frontend and logging S3 buckets lacked default SSE-KMS customer-managed encryption | `terraform/modules/s3/main.tf:135, 175` | Added `aws_s3_bucket_server_side_encryption_configuration` with KMS key ARN (`aws:kms`) and bucket keys enabled across all four S3 buckets. |
| 6 | MEDIUM | Data Integrity / Replay | Image processor created random UUID per invocation, allowing duplicate S3 events to duplicate items | `lambda/image-processor/handler.py:65`, `metadata.py:31` | Enforced idempotency: computed deterministic SHA-256 hash from S3 bucket + key as `image_id`. Added `ConditionExpression="attribute_not_exists(image_id)"` to DynamoDB `put_item`. |
| 7 | MEDIUM | Perimeter Defense | WAF SQL injection and cross-site scripting rules previously inspected only query strings | `terraform/future/waf/main.tf:108, 178` | Added URI path inspection via `or_statement` combining `query_string` and `uri_path` match statements with lowercase and URL decoding transformations. |
| 8 | MEDIUM | S3 Transport Security | Processed variants and access logs buckets lacked TLS deny policy | `terraform/modules/s3/main.tf:112, 185` | Configured explicit bucket policies denying `s3:*` when `aws:SecureTransport` is `false`. |
| 9 | MEDIUM | Client Authorization | Frontend previously uploaded directly to S3 without IAM identity binding | `frontend/src/Upload.js:67-77` | Bound uploads to Cognito Identity Pool temporary STS credentials with scoped S3 `PutObject` policy. (Mock server handles local development). |
| 10 | MEDIUM | IAM Assume Scope | Step Functions and EventBridge trust policies lacked source account scoping | `terraform/modules/iam/main.tf:161, 198` | Added `StringEquals` condition matching `aws:SourceAccount` against caller account ID to prevent confused deputy attacks. |
| 11 | MEDIUM | API Validation | API Gateway accepted unvalidated path and query parameters | `terraform/modules/api-gateway/main.tf:33, 46, 61` | Configured `aws_api_gateway_request_validator` with parameter validation enforced on all GET endpoints. |
| 12 | LOW | CI/CD Integrity | Dependency vulnerability check bypassed failure using `\|\| true` | `.github/workflows/ci.yml` | Removed all `\|\| true` escape hatches; workflow fails build on unpatched vulnerabilities or failed checks. |
| 13 | LOW | IaC Security | Terraform state bucket lacked server-side encryption and versioning in instructions | `terraform/backend.tf:8-15` | Documented and configured KMS encryption and bucket versioning for remote state management. |
| 14 | LOW | Client-side XSS | Dynamic DOM updates previously used `innerHTML` with unsanitized user inputs | `frontend/src/Gallery.js:48-73`, `Upload.js:40-65` | Refactored all DOM manipulation to use `document.createElement()` and `textContent`. Eliminated all dynamic HTML string concatenation. |
| 15 | LOW | Least Privilege IAM | Single `Resource: "*"` occurrence identified in KMS key policy | `terraform/modules/kms/main.tf:17` | Verified requirement per AWS KMS key policy specification (root account principal delegation); documented risk acceptance in code comment. |
| 16 | LOW | DoS Mitigation | Image decompression bomb vulnerability (decompression DOS) | `lambda/image-processor/resize.py:22-26` | Added `MAX_IMAGE_DIMENSION = 10000` and `MAX_IMAGE_PIXELS = 50_000_000` guards prior to executing PIL resize operations. |

---

## 3. Detailed Audit by Subsystem

### 3.1 IAM Least Privilege Audit
- **Wildcard Scan:** Grepped all Terraform definitions for `resources = ["*"]` and `Resource: "*"`.
- **Result:** Exactly 1 occurrence found in `terraform/modules/kms/main.tf:17`.
  - *Justification:* In AWS KMS key policies, the resource element must be `"*"` because the policy is embedded directly on the KMS key resource. Root account delegation to account IAM principals requires this syntax.
- **Lambda Execution Roles:**
  - `ImageProcessorRole`: Restricted strictly to `s3:GetObject` on `uploads/*`, `s3:PutObject` on `processed/*`, `dynamodb:PutItem`/`UpdateItem` on the metadata table, and `kms:Decrypt`/`GenerateDataKey` on the key ARN. Zero wildcard actions or resources.
  - `ImageAPIRole`: Restricted strictly to `dynamodb:Query`/`GetItem` on the metadata table and GSI indexes, and `kms:Decrypt` on the KMS key ARN.

### 3.2 S3 Bucket Security Audit
All four buckets (`uploads`, `processed`, `frontend`, `logs`) verify the following controls:
1. **Block Public Access:** All four settings (`block_public_acls`, `block_public_policy`, `ignore_public_acls`, `restrict_public_buckets`) are set to `true`.
2. **TLS Enforcement:** Explicit `Deny` policy applied to all non-HTTPS requests (`aws:SecureTransport == false`).
3. **SSE-KMS Encryption:** Configured with `aws:kms` using the project's customer-managed KMS key and bucket keys enabled.
4. **Lifecycle Rules:** Configured across all buckets (non-current version expiration, log transitions to Standard-IA after 30 days and expiration after 90 days).

### 3.3 API Gateway and CloudFront Audit
- **CORS:** Restricted to explicitly configured origins via `ALLOWED_ORIGINS` environment variable. Wildcard `*` default removed.
- **Request Validation:** Request validator resource (`aws_api_gateway_request_validator`) attached to `/images` and `/images/{image_id}` methods.
- **Origin Access Control (OAC):** CloudFront accesses S3 using modern Origin Access Control (`aws_cloudfront_origin_access_control`), eliminating legacy Origin Access Identity (OAI).
- **Security Headers:** Strict response headers policy attached to both CloudFront distributions.

### 3.4 Lambda Runtime Security Audit
- **Environment Variables:** Contains no secrets, database passwords, or credentials. Only resource identifiers (`METADATA_TABLE`, `PROCESSED_BUCKET`, `KMS_KEY_ARN`, `ALLOWED_ORIGINS`).
- **Code Execution:** Zero occurrences of `eval()`, `exec()`, or `pickle.loads()`.
- **Input Validation:**
  - MIME type validation against strict allowlist: `image/jpeg`, `image/png`, `image/webp`.
  - File size cap: 50 MB maximum.
  - Pillow image verification: verifies headers and enforces maximum dimensions (10,000 px) and total pixel count (50,000,000 pixels) to prevent decompression bombs ("pixel bombs").
- **Idempotency:** Deterministic SHA-256 ID prevents duplicate records upon S3 event redelivery.

---

## 4. Automated Secret Detection (Gitleaks Output)

Command executed on repository root:
```bash
gitleaks detect --source . --verbose --no-git
```

Verbatim Output:
```
    ○
    │╲
    │ ○
    ○ ░
    ░    gitleaks

INF scan completed in 365ms
INF no leaks found
```

### Pattern Matcher Scan
Command executed:
```bash
grep -rn -E "(AKIA|aws_secret|password\s*=\s*\"[^\"]+\")" .
```
Result: `0 hits` (clean). All credentials use `YOUR_` placeholders.
