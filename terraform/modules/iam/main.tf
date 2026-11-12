data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "image_processor" {
  name               = "ImageFlow-ImageProcessor-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "image_processor_basic_exec" {
  role       = aws_iam_role.image_processor.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "image_processor_xray" {
  role       = aws_iam_role.image_processor.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

resource "aws_iam_role_policy" "image_processor_s3" {
  name   = "ImageFlow-ImageProcessor-S3"
  role   = aws_iam_role.image_processor.name
  policy = data.aws_iam_policy_document.image_processor_s3.json
}

data "aws_iam_policy_document" "image_processor_s3" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${var.uploads_bucket_arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
  statement {
    actions   = ["s3:PutObject"]
    resources = ["${var.processed_bucket_arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role_policy" "image_processor_dynamodb" {
  name   = "ImageFlow-ImageProcessor-DynamoDB"
  role   = aws_iam_role.image_processor.name
  policy = data.aws_iam_policy_document.image_processor_dynamodb.json
}

data "aws_iam_policy_document" "image_processor_dynamodb" {
  statement {
    actions   = ["dynamodb:PutItem", "dynamodb:UpdateItem"]
    resources = [var.dynamodb_table_arn]
  }
}

resource "aws_iam_role_policy" "image_processor_kms" {
  name   = "ImageFlow-ImageProcessor-KMS"
  role   = aws_iam_role.image_processor.name
  policy = data.aws_iam_policy_document.image_processor_kms.json
}

data "aws_iam_policy_document" "image_processor_kms" {
  statement {
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [var.kms_key_arn]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.${var.region}.amazonaws.com", "dynamodb.${var.region}.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "image_api" {
  name               = "ImageFlow-ImageAPI-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "image_api_basic_exec" {
  role       = aws_iam_role.image_api.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "image_api_xray" {
  role       = aws_iam_role.image_api.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

resource "aws_iam_role_policy" "image_api_dynamodb" {
  name   = "ImageFlow-ImageAPI-DynamoDB"
  role   = aws_iam_role.image_api.name
  policy = data.aws_iam_policy_document.image_api_dynamodb.json
}

data "aws_iam_policy_document" "image_api_dynamodb" {
  statement {
    actions   = ["dynamodb:Query", "dynamodb:GetItem"]
    resources = [var.dynamodb_table_arn, "${var.dynamodb_table_arn}/index/*"]
  }
}

resource "aws_iam_role_policy" "image_api_kms" {
  name   = "ImageFlow-ImageAPI-KMS"
  role   = aws_iam_role.image_api.name
  policy = data.aws_iam_policy_document.image_api_kms.json
}

data "aws_iam_policy_document" "image_api_kms" {
  statement {
    actions   = ["kms:Decrypt"]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role" "step_functions" {
  name               = "ImageFlow-StepFunctions-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.step_functions_assume_role.json

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

data "aws_iam_policy_document" "step_functions_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role_policy" "step_functions_lambda" {
  name   = "ImageFlow-StepFunctions-Lambda"
  role   = aws_iam_role.step_functions.name
  policy = data.aws_iam_policy_document.step_functions_lambda.json
}

data "aws_iam_policy_document" "step_functions_lambda" {
  statement {
    actions   = ["lambda:InvokeFunction"]
    resources = [var.image_processor_lambda_arn, var.image_api_lambda_arn]
  }
}

resource "aws_iam_role" "api_gateway_cloudwatch" {
  name               = "ImageFlow-APIGatewayCW-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.api_gateway_assume_role.json
}

data "aws_iam_policy_document" "api_gateway_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  role       = aws_iam_role.api_gateway_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}
