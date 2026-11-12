resource "aws_sfn_state_machine" "this" {
  name     = "ImageFlow-Processor-${var.environment}"
  role_arn = var.role_arn
  type     = "STANDARD"

  definition = jsonencode({
    Comment = "Image processing pipeline: validate -> resize -> blurhash -> metadata -> notify"
    StartAt = "ValidateImageType"
    States = {
      ValidateImageType = {
        Type = "Pass"
        Parameters = {
          "image_type.$" = "$.detail.object.key"
        }
        ResultPath = "$.validation"
        Next       = "ResizeVariants"
      }
      ResizeVariants = {
        Type = "Parallel"
        Branches = [
          {
            StartAt = "ResizeThumbnail"
            States = {
              ResizeThumbnail = {
                Type     = "Task"
                Resource = var.image_processor_lambda_arn
                Parameters = {
                  "variant"  = "thumbnail"
                  "bucket.$" = "$.detail.bucket.name"
                  "key.$"    = "$.detail.object.key"
                }
                ResultPath = "$.thumbnail"
                End        = true
              }
            }
          },
          {
            StartAt = "ResizeWeb"
            States = {
              ResizeWeb = {
                Type     = "Task"
                Resource = var.image_processor_lambda_arn
                Parameters = {
                  "variant"  = "web"
                  "bucket.$" = "$.detail.bucket.name"
                  "key.$"    = "$.detail.object.key"
                }
                ResultPath = "$.web"
                End        = true
              }
            }
          },
          {
            StartAt = "GenerateBlurhash"
            States = {
              GenerateBlurhash = {
                Type     = "Task"
                Resource = var.image_processor_lambda_arn
                Parameters = {
                  "action"   = "blurhash"
                  "bucket.$" = "$.detail.bucket.name"
                  "key.$"    = "$.detail.object.key"
                }
                ResultPath = "$.blurhash"
                End        = true
              }
            }
          }
        ]
        ResultPath = "$.variants"
        Next       = "UpdateMetadata"
      }
      UpdateMetadata = {
        Type     = "Task"
        Resource = var.image_api_lambda_arn
        Parameters = {
          "action"     = "update_metadata"
          "image_id.$" = "$.detail.image_id"
          "variants.$" = "$.variants"
          "blurhash.$" = "$.blurhash.hash"
        }
        ResultPath = "$.metadata"
        Next       = "NotifyCompletion"
      }
      NotifyCompletion = {
        Type     = "Task"
        Resource = "arn:aws:states:::events:putEvents"
        Parameters = {
          Entries = [{
            EventBusName = var.event_bus_name
            Source       = "imageflow.stepfunctions"
            DetailType   = "ImageProcessingComplete"
            "Detail.$"   = "$.metadata"
          }]
        }
        End = true
      }
    }
  })

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
