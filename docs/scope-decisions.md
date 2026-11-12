# Architecture Scope Decisions and Rationales

**Author and Architecture Lead:** Mihir Modi  
**Role:** 2nd-Year BTech Computer Engineering  
**Project:** AWS Serverless ImageFlow  

---

## Executive Summary

A common pitfall in junior cloud portfolios is "resume-driven infrastructure": provisioning every service listed on an AWS certification guide regardless of whether the application requires it, whether it works without manual intervention, or what it costs while sitting idle.

This project deliberately applies scope discipline. Services that do not have active application integration, that block local zero-credential validation, or that incur substantial idle costs without traffic have been either removed or moved to `terraform/future/` with clear operational requirements for re-enabling them.

This document demonstrates architectural judgment: knowing when **not** to provision a service is as vital as knowing how to configure it.

---

## 1. AWS WAFv2 (Web Application Firewall)

### What was cut
The `terraform/modules/waf` module was moved from the active deployment path to `terraform/future/waf/`. It previously attached a Regional/Global Web ACL containing 5 inspection rules (Rate Limiting, AWS IP Reputation list, Known Bad Inputs, SQL Injection with URI inspection, and Cross-Site Scripting with URI inspection) to the CloudFront distributions.

### Why
- **Cost:** AWS WAF charges a baseline fee of $5.00/month per Web ACL plus $1.00/month per active rule. The 5 rules in this module generated a fixed, non-negotiable cost of **$10.00/month** ($120/year) even if zero HTTP requests were received.
- **Testing friction:** WAF cannot be validated locally without an active AWS environment and live CloudFront edge nodes.
- **Narrative vs Reality:** Without an active penetration testing harness or rate-limit test script, keeping WAF active was purely decorative.

### What it would take to add back
1. Move `terraform/future/waf` back to `terraform/modules/waf`.
2. Re-enable the module in `terraform/live/dev/main.tf` and pass `waf_acl_arn = module.waf.web_acl_arn` into `module.cloudfront`.
3. Run `terraform apply`.

### Which interview question it prepares you for
*"How do you balance defense-in-depth security against cloud operational cost on early-stage serverless workloads?"*  
**Spoken answer:** "On production enterprise workloads facing public traffic, WAF is non-negotiable for DDoS mitigation and OWASP Top 10 filtering. However, for an idle prototype or internal development environment, an idle Web ACL with custom rules burns $10/month per distribution. In this architecture, I decoupled WAF into a validated future module and enforced origin shielding, CloudFront security response headers, strict CORS, and S3 Origin Access Control as zero-cost baseline defenses, keeping WAF ready to attach once ingress traffic warrants the cost."

---

## 2. Amazon Cognito (User Pools and Identity Pools)

### What was cut
The `terraform/modules/cognito` module was moved to `terraform/future/cognito/`. It previously provisioned a Cognito User Pool with Hosted UI, App Client with OAuth2 implicit/code grant flows, and an Identity Pool providing temporary STS credentials for direct browser-to-S3 uploads.

### Why
- **Local testing blockers:** Cognito Hosted UI redirects to an AWS-hosted domain (`auth.us-east-1.amazoncognito.com`). Reviewers running the frontend locally without an AWS account cannot sign in, which blocked evaluating the core image resizing UI.
- **Operational overhead:** User pools require DNS configuration, email delivery verification, and callback URL management that divert focus from the primary compute model: event-driven asynchronous processing.
- **Zero-friction demo:** Decoupling authentication allows the frontend to run against a standalone local mock server (`node frontend/mock-server.js`) with instant drag-and-drop feedback.

### What it would take to add back
1. Move `terraform/future/cognito` back to `terraform/modules/cognito`.
2. In `terraform/live/dev/main.tf`, re-enable the module and pass `cognito_user_pool_arn = module.cognito.user_pool_arn` to `module.api_gateway`.
3. In `frontend/src/App.js`, populate `userPoolId`, `clientId`, and `identityPoolId` from Terraform outputs.

### Which interview question it prepares you for
*"When would you use Cognito Identity Pools for S3 uploads versus API Gateway presigned URLs?"*  
**Spoken answer:** "Cognito Identity Pools issue temporary scoped IAM credentials directly to the browser using AWS STS, allowing the client to execute multipart uploads directly to S3 via the AWS SDK. This completely bypasses API Gateway payload limits (10 MB maximum) and eliminates API Gateway data transfer charges. However, it requires bundling the AWS JavaScript SDK into the client. Presigned URLs, by contrast, allow a lightweight client without AWS dependencies to upload via standard HTTP PUT, but require an initial API round-trip to generate the presigned URL."

---

## 3. AWS Step Functions

### What was cut
The `terraform/modules/step-functions` module was moved to `terraform/future/step-functions/`. It defined an Express/Standard state machine intended to orchestrate image validation, parallel variant generation, and DynamoDB updates.

### Why
- **Architectural mismatch:** S3 `ObjectCreated` notifications trigger the `image-processor` Lambda function directly and asynchronously. The processor handler executes the 3 resizes (thumbnail, web, preview) in-memory using Pillow in under 800ms.
- **Over-orchestration:** Wrapping a sub-second, single-event transformation in a multi-state Step Functions workflow introduced unnecessary state transition latency, extra IAM roles, and complexity without delivering distributed coordination benefits.
- **Handler interface:** The Lambda handler was designed around S3Event records, not Step Functions task event inputs. Keeping both in the codebase caused architectural ambiguity.

### What it would take to add back
1. Move `terraform/future/step-functions` back to `terraform/modules/step-functions`.
2. Refactor `image-processor` into modular single-purpose task functions (`validate-task`, `resize-task`, `metadata-task`).
3. Configure S3 EventBridge notifications to trigger the state machine instead of direct Lambda notifications.

### Which interview question it prepares you for
*"When is Step Functions appropriate versus direct S3-to-Lambda event notification?"*  
**Spoken answer:** "Direct S3-to-Lambda notification is optimal when processing is short-lived (< 15 minutes), fits within Lambda memory limits, and failures can be handled via built-in async retry policies and SQS Dead-Letter Queues. Step Functions becomes essential when the workflow involves long-running asynchronous tasks (e.g., human-in-the-loop content moderation, multi-stage ML inference with Rekognition), distributed sagas requiring compensating transactions across multiple services, or complex conditional branch logic with visual observability."

---

## 4. Amazon EventBridge Custom Event Bus

### What was cut
The EventBridge IAM assume roles and custom event bus local configurations (`imageflow-bus-dev`) were deleted from `terraform/modules/iam/`.

### Why
- **Duplication and dead code:** The application code did not emit or subscribe to custom EventBridge events. The primary event pipeline is native S3-to-Lambda event notifications. Provisioning an empty event bus with IAM write policies was dead infrastructure.
- **Least privilege:** Removing unused IAM roles prevents permission creep and eliminates unused attack surface.

### What it would take to add back
1. Add `aws_cloudwatch_event_bus` resource in Terraform.
2. In `handler.py`, call `events_client.put_events()` to publish `ImageProcessingCompleted` notifications to downstream subscribers (e.g., search indexing, analytics).

### Which interview question it prepares you for
*"How do you choose between S3 Event Notifications, SNS, and EventBridge for event routing?"*  
**Spoken answer:** "Direct S3 event notifications provide the lowest latency and zero cost for 1-to-1 fanout to a single Lambda, SQS, or SNS target. Amazon SNS is ideal for high-throughput 1-to-many fanout where subscribers need push notifications. EventBridge is the premier choice when events require content-based filtering, schema registry validation, or routing across multiple AWS accounts and SaaS integrations."

---

## 5. Standalone CloudTrail and AWS CodePipeline

### What was cut
- `monitoring/trail.yaml` (CloudFormation management trail)
- `pipeline/pipeline.yaml` and `pipeline/buildspec.yml` (AWS CodePipeline / CodeBuild)

### Why
- **Tooling consistency:** The project standardized on **Terraform** for Infrastructure as Code and **GitHub Actions** for CI/CD. Maintaining duplicate CloudFormation and CodePipeline templates caused configuration drift and created confusing dual maintenance paths.
- **Portability:** GitHub Actions allows complete automated linting, pytest unit testing, SAST analysis, and Terraform validation on public GitHub runners without requiring an active AWS account.

### What it would take to add back
- CloudTrail can be enabled via an organizational Terraform module when compliance auditing across management events is required.
- CodePipeline can be restored if enterprise security mandates that deployment pipelines run strictly inside a private AWS VPC without third-party CI runners.

### Which interview question it prepares you for
*"Why choose GitHub Actions over AWS CodePipeline for a modern multi-environment serverless pipeline?"*  
**Spoken answer:** "GitHub Actions keeps CI/CD definitions directly alongside the application source code with native PR status checks, branch protection rules, and access to thousands of reusable community actions. It allows running pre-deployment security gates (Checkov, tfsec, Bandit, Gitleaks) in ephemeral runners completely free of cloud infrastructure costs. AWS CodePipeline is valuable for strict VPC-isolated enterprise deployments, but introduces higher configuration friction for developer-centric GitOps workflows."

---

## Cost Impact of Scope Reduction

| Metric | Original 10-Module Stack | Reduced Deployed Stack | Savings |
|--------|--------------------------|------------------------|---------|
| **Monthly Idle Cost (24/7, 0 traffic)** | **$11.02/month** | **$1.02/month** | **90.7% reduction ($10.00/mo saved)** |
| **Primary Cost Driver** | WAF Web ACL ($5) + 5 Rules ($5) | KMS Customer-Managed Key ($1) | Eliminated idle firewall fees |
| **1-Hour Demo Cost** | ~$0.05 | ~$0.02 | 60% reduction |
| **Local Verifiability** | Blocked by Cognito | 100% locally testable | Zero cloud credentials needed |

By eliminating decorative modules, we reduced idle cloud costs from $132/year to $12/year while making the entire codebase locally testable.
