# Future Scope: Amazon Cognito (User Pools and Identity Pools)

## Overview
This module provisions an Amazon Cognito User Pool with Hosted UI and App Client, plus an Identity Pool with IAM role attachment granting authenticated STS temporary credentials for client-side uploads.

## Why It Was Moved Out of the Active Deployed Path
1. **Local preview ergonomics:** Requiring a live Cognito User Pool blocks running and evaluating the frontend SPA locally. Without live deployment, sign-in redirects to an unresolvable AWS endpoint.
2. **Setup complexity:** Cognito requires DNS domain configuration, callback URL alignment, and user verification workflows that add friction to quick portfolio evaluations.
3. **Scope separation:** Decoupling user authentication allows reviewers to evaluate the core event-driven image pipeline (upload, resize, DynamoDB metadata, CloudFront CDN) without authentication prerequisites.

## How to Re-Enable
1. Move the module back to `terraform/modules/cognito/`:
   ```bash
   mv terraform/future/cognito terraform/modules/cognito
   ```
2. Re-enable the module in `terraform/live/dev/main.tf` and `terraform/live/prod/main.tf`:
   ```hcl
   module "cognito" {
     source             = "../../modules/cognito"
     environment        = var.environment
     cognito_domain     = var.cognito_domain
     callback_urls      = var.cognito_callback_urls
     logout_urls        = var.cognito_logout_urls
     uploads_bucket_arn = module.s3.uploads_bucket_arn
   }
   ```
3. Pass `cognito_user_pool_arn = module.cognito.user_pool_arn` into `module.api_gateway`.
4. Update `frontend/src/App.js` with the provisioned User Pool ID, Client ID, and Cognito Domain.
