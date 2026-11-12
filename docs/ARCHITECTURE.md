# AWS Serverless ImageFlow - Architecture

> **Made by Mihir Modi** - BTech Computer Engineering, Gujarat

## Data Flow Diagrams

### Synchronous Path (User → Frontend → Upload)

```
User Browser
    │
    ├── 1. Navigate to CloudFront URL
    │       │
    │       ▼
    │   CloudFront (Frontend)
    │       │
    │       ▼
    │   S3 (Frontend Bucket) ──► index.html + JS + CSS
    │
    ├── 2. Sign in via Cognito Hosted UI
    │       │
    │       ▼
    │   Cognito User Pool ──► ID Token + Access Token
    │
    ├── 3. Upload image (drag-drop or browse)
    │       │
    │       ▼
    │   Direct to S3 (Uploads Bucket)
    │   (Pre-signed or authenticated PUT)
    │
    └── 4. View Gallery
            │
            ▼
        API Gateway (GET /images) ──► Lambda ImageAPI ──► DynamoDB
            │
            ▼
        CloudFront (Images CDN) ──► S3 (Processed) ──► Thumbnails
```

### Asynchronous Path (S3 Event → Pipeline → CDN)

```
S3: Uploads Bucket
    │
    └── s3:ObjectCreated:* notification
            │
            ▼
    Lambda: ImageProcessor
        │   ├── Download original image
        │   ├── Resize variants (thumbnail 150×150, web 800×800, preview 400×400)
        │   ├── Generate blurhash
        │   └── Write metadata to DynamoDB
        │
        ├──► S3: Processed Bucket
        │       └── thumbnail_*.jpg, web_*.jpg, preview_*.jpg
        │
        ├──► DynamoDB: ImageMetadata
        │       └── image_id (PK), upload_date (SK), variants, blurhash, status
        │
        └──► EventBridge: Custom Event Bus
                └── ImageProcessingComplete event
```

### Step Functions State Machine

```
Start ──► ValidateImageType ──► Parallel Branch
                                    │
                    ┌───────────────┼───────────────┐
                    ▼               ▼               ▼
            ResizeThumbnail    ResizeWeb     GenerateBlurhash
              (150×150)        (800×800)      (4×3 components)
                    │               │               │
                    └───────────────┼───────────────┘
                                    ▼
                            UpdateMetadata
                              (DynamoDB)
                                    │
                                    ▼
                           NotifyCompletion
                          (EventBridge event)
                                    │
                                    ▼
                                   End
```

### Error Handling Flow

```
S3 Event ──► Lambda Invoke
                │
                ├── Success ──► S3 (processed) + DynamoDB
                │
                └── Error ──► Retry (max 3)
                                │
                                ├── Success ──► Process
                                │
                                └── Fail ──► SQS DLQ
                                              │
                                              ▼
                                        CloudWatch Alarm
                                              │
                                              ▼
                                        SNS Notification
```

---

## IAM Role Trust Relationships

```
Lambda ImageProcessor
    AssumeRole: lambda.amazonaws.com
    Condition: aws:SourceAccount = ${AWS::AccountId}
    Permissions:
        s3:GetObject on uploads-bucket/*
        s3:PutObject on processed-bucket/*
        dynamodb:PutItem, UpdateItem on ImageMetadata
        kms:Decrypt, GenerateDataKey via kms:ViaService (s3, dynamodb)

Lambda ImageAPI
    AssumeRole: lambda.amazonaws.com
    Permissions:
        dynamodb:Query, GetItem on ImageMetadata + indexes
        kms:Decrypt

Step Functions
    AssumeRole: states.amazonaws.com
    Permissions:
        lambda:InvokeFunction on both Lambdas

EventBridge
    AssumeRole: events.amazonaws.com
    Permissions:
        dynamodb:Query, Scan on ImageMetadata
        s3:DeleteObject on uploads-bucket/*
        kms:Decrypt

Cognito Identity Pool (Authenticated)
    AssumeRoleWithWebIdentity: cognito-identity.amazonaws.com
    Permissions:
        s3:PutObject on uploads-bucket/*
```

---

## Network Flow

```
                         Internet
                            │
                            ▼
                    ┌───────────────┐
                    │   WAF Web ACL │
                    │  (rate, SQLi, │
                    │   XSS, common)│
                    └───────┬───────┘
                            │
                    ┌───────┴───────┐
                    │  CloudFront   │
                    └───────┬───────┘
                            │
            ┌───────────────┴───────────────┐
            │                               │
    ┌───────┴───────┐               ┌───────┴───────┐
    │  S3 Frontend  │               │ S3 Processed  │
    │ (OAC only)    │               │ (OAI only)    │
    └───────────────┘               └───────────────┘
                                            │
                                    Lambda ImageProcessor
                                            │
                                    ┌───────┴───────┐
                                    │   DynamoDB    │
                                    └───────────────┘

API Gateway (Regional endpoint)
    │
    ├── Lambda ImageAPI
    │       └── DynamoDB
    │
    └── CloudWatch Logs + X-Ray

All services are within the same AWS account and region (us-east-1).
No VPC is required - Lambda functions use the default public VPC or no VPC.
S3 bucket policies enforce SSL-only access.
KMS keys have IAM policies scoped to specific principals.
