# Future Scope: AWS Step Functions Pipeline Orchestrator

## Overview
This module defines a state machine for multi-stage image processing orchestration: validating image types, executing parallel variant resizing tasks, updating DynamoDB metadata, and emitting an EventBridge completion event.

## Why It Was Moved Out of the Active Deployed Path
1. **Direct S3 event trigger simplicity:** In the current architecture, S3 `ObjectCreated` events trigger the `image-processor` Lambda function directly. This eliminates orchestration overhead and reduces cold-start invocation latency.
2. **Implementation mismatch:** The `image-processor` Lambda is designed to parse S3Event records directly, whereas the Step Functions state machine passes structured JSON task payloads (`variant: thumbnail`). Step Functions requires a dispatcher Lambda or dedicated task handlers.
3. **Simplicity over abstraction:** For an image resizing pipeline generating 3 variants synchronously, direct asynchronous Lambda execution with an SQS dead-letter queue is more cost-effective and architecturally concise.

## How to Re-Enable
1. Move the module back to `terraform/modules/step-functions/`:
   ```bash
   mv terraform/future/step-functions terraform/modules/step-functions
   ```
2. Refactor `image-processor` into separate task handlers (e.g. `resize_task.py`, `metadata_task.py`) or add input dispatch logic.
3. Configure EventBridge S3 notifications to trigger the Step Functions execution execution role.
4. Re-enable in `terraform/live/dev/main.tf`.
