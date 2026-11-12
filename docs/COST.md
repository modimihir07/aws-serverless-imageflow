# AWS Serverless ImageFlow - Cost Analysis

> **Made by Mihir Modi** - BTech Computer Engineering, Gujarat

## Free Tier Eligibility

This project is designed to run within AWS Free Tier limits for the first 12 months.

| Service | Free Tier Limit | ImageFlow Usage | Free? |
|---------|----------------|-----------------|-------|
| **Lambda** | 1M requests/mo, 400K GB-seconds | ~10K req/mo (dev), ~500K req/mo (prod) | ✅ Free |
| **S3** | 5GB standard, 20K GET, 2K PUT | ~1GB (dev), ~10GB (prod) | ✅ Free (dev) |
| **API Gateway** | 1M API calls/mo | ~5K calls/mo (dev), ~800K (prod) | ✅ Free (dev) |
| **DynamoDB** | 25GB storage, 25 RCU/WCU on-demand | ~100MB, minimal reads/writes | ✅ Free |
| **CloudFront** | 1TB transfer, 10M requests/mo | ~50GB (dev), ~200GB (prod) | ✅ Free |
| **Cognito** | 50K MAU | ~10 users (dev), ~100 users (prod) | ✅ Free |
| **CloudWatch** | 10 dashboards, 10 alarms, 5GB logs | 1 dashboard, 5 alarms, ~100MB logs | ✅ Free |
| **SQS** | 1M requests/mo | Negligible | ✅ Free |
| **Step Functions** | 4K state transitions/mo | ~500 transitions/mo (dev) | ✅ Free (dev) |
| **WAF** | 5 ACLs (first month free) | 1 ACL | ✅ Free (month 1) |
| **KMS** | 20K requests/mo | ~500 requests/mo | ✅ Free |
| **X-Ray** | 100K traces/mo, 1M annotations | ~5K traces/mo | ✅ Free |
| **EventBridge** | Custom events: $1/M events | Negligible | ✅ Free |
| **ACM** | Private CA $400/mo (but public certs free) | Public certs via ACM = Free | ✅ Free |
| **CloudTrail** | 1 trail per region free | 1 trail | ✅ Free |

**Dev Environment: $0/mo** - entirely within free tier.

## Beyond Free Tier (Prod, Heavy Usage)

| Service | Volume | Monthly Cost |
|---------|--------|-------------|
| API Gateway | 10M requests | $3.50 |
| Lambda | 2M requests, 500K GB-seconds | $2.00 |
| S3 | 50GB standard, 2M requests | $1.50 |
| DynamoDB | 10GB on-demand | $2.00 |
| CloudFront | 500GB transfer, 5M requests | $5.00 |
| WAF | 1 web ACL (after first month) | $6.00 |
| CloudWatch | 10GB logs, custom metrics | $3.00 |
| **Total** | | **~$23/mo** |

## Cost Optimization Tips

1. **S3 Lifecycle Policies** - Already configured: IA after 30d, Glacier after 90d, delete after 365d
2. **Lambda Provisioned Concurrency** - Not used (stays within free tier)
3. **CloudFront Price Class** - Uses `PriceClass_100` (US+Europe only) for dev, `PriceClass_All` for prod
4. **DynamoDB On-Demand** - PAY_PER_REQUEST billing (no provisioned capacity waste)
5. **API Gateway Usage Plans** - Monthly quotas prevent runaway costs
6. **CloudWatch Budget Alarm** - Alerts at 80% and 100% of $10 (dev) / $50 (prod) budget
7. **Reserved Concurrency** - Lambda capped at 5 (dev) / 10 (prod) concurrent executions

## Budget Alert Configuration

```yaml
# Deployed via CloudFormation (cloudformation/main.yaml)
# Alerts sent to YOUR_EMAIL_ADDRESS
BudgetLimit:
  Amount: 10   # Dev: $10
  # Amount: 50 # Prod: $50
Notifications:
  - Threshold: 80%  # Warning at $8
  - Threshold: 100% # Critical at $10
```

## Cost Comparison: Serverless vs Containerized

| Aspect | Serverless ImageFlow | CloudMart 2.0 (EKS) |
|--------|-------------------|---------------------|
| **Compute** | Lambda (free tier) | EKS nodes (2× t4g.micro ~$30/mo) |
| **Database** | DynamoDB (free tier) | RDS PostgreSQL (~$15/mo) |
| **Dev cost** | **$0/mo** | **~$45/mo** |
| **Prod cost** | **~$23/mo** | **~$200-400/mo** |

Serverless is dramatically cheaper for low-traffic workloads!
