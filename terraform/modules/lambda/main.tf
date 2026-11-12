resource "aws_lambda_function" "image_processor" {
  filename                       = var.processor_package_path
  function_name                  = "ImageFlow-ImageProcessor-${var.environment}"
  role                           = var.processor_role_arn
  handler                        = "handler.handler"
  runtime                        = "python3.12"
  timeout                        = 300
  memory_size                    = 512
  reserved_concurrent_executions = var.environment == "prod" ? 10 : 5

  environment {
    variables = {
      PROCESSED_BUCKET = var.processed_bucket_id
      METADATA_TABLE   = var.dynamodb_table_name
      KMS_KEY_ARN      = var.kms_key_arn
      LOG_LEVEL        = var.environment == "prod" ? "INFO" : "DEBUG"
    }
  }

  tracing_config {
    mode = "Active"
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_lambda_function" "image_api" {
  filename                       = var.api_package_path
  function_name                  = "ImageFlow-ImageAPI-${var.environment}"
  role                           = var.api_role_arn
  handler                        = "handler.handler"
  runtime                        = "python3.12"
  timeout                        = 30
  memory_size                    = 128
  reserved_concurrent_executions = var.environment == "prod" ? 20 : 10

  environment {
    variables = {
      METADATA_TABLE  = var.dynamodb_table_name
      LOG_LEVEL       = var.environment == "prod" ? "INFO" : "DEBUG"
      ALLOWED_ORIGINS = var.allowed_origins
    }
  }

  tracing_config {
    mode = "Active"
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_lambda_permission" "image_processor_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.uploads_bucket_arn
}

resource "aws_lambda_permission" "image_api_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.api_gateway_exec_arn}/*/*"
}

resource "aws_s3_bucket_notification" "uploads_notification" {
  bucket = var.uploads_bucket_id
  lambda_function {
    lambda_function_arn = aws_lambda_function.image_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".jpg"
  }
  lambda_function {
    lambda_function_arn = aws_lambda_function.image_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".png"
  }
  lambda_function {
    lambda_function_arn = aws_lambda_function.image_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".jpeg"
  }
  depends_on = [aws_lambda_permission.image_processor_s3]
}

resource "aws_sqs_queue" "dlq" {
  name                       = "ImageFlow-DLQ-${var.environment}"
  message_retention_seconds  = 1209600
  visibility_timeout_seconds = 300

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_lambda_function_event_invoke_config" "processor_dlq" {
  function_name          = aws_lambda_function.image_processor.function_name
  maximum_retry_attempts = 2
  destination_config {
    on_failure {
      destination = aws_sqs_queue.dlq.arn
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "dlq_alarm" {
  alarm_name          = "ImageFlow-DLQ-Messages-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alarm when DLQ has messages"
  alarm_actions       = []
  dimensions = {
    QueueName = aws_sqs_queue.dlq.name
  }
}
