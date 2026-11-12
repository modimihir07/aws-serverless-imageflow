# Future Scope: AWS WAFv2 Web ACL

## Overview
This module contains the AWS WAFv2 Web ACL configuration designed to protect CloudFront distributions against common web exploits, rate abuse, SQL injection, and cross-site scripting (XSS).

## Why It Was Moved Out of the Active Deployed Path
1. **Cost optimization:** An active WAF Web ACL costs $5.00/month flat fee plus $1.00/month per active rule. With 5 rules enabled (RateLimit, IPReputation, KnownBadInputs, SQLi, and XSS), the idle cost is $10.00/month even with zero incoming traffic.
2. **Local testing friction:** WAF rules cannot be tested locally without an active AWS account and live CloudFront edge deployment.
3. **Credibility:** Including a decorative security service without an active WAF attack test suite undermines portfolio honesty.

## How to Re-Enable
1. Move the module back to `terraform/modules/waf/`:
   ```bash
   mv terraform/future/waf terraform/modules/waf
   ```
2. In `terraform/live/dev/main.tf` and `terraform/live/prod/main.tf`, re-add the module instantiation:
   ```hcl
   module "waf" {
     source      = "../../modules/waf"
     environment = var.environment
     rate_limit  = var.environment == "prod" ? 5000 : 2000
   }
   ```
3. Pass `waf_acl_arn = module.waf.web_acl_arn` into `module.cloudfront`.
4. Run `terraform apply`.
