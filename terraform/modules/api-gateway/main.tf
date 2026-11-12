resource "aws_api_gateway_rest_api" "this" {
  name        = "ImageFlow-API-${var.environment}"
  description = "Serverless ImageFlow REST API"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_api_gateway_resource" "images" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "images"
}

resource "aws_api_gateway_resource" "images_item" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.images.id
  path_part   = "{image_id}"
}

resource "aws_api_gateway_resource" "health" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "health"
}

resource "aws_api_gateway_request_validator" "validate_all" {
  name                        = "ImageFlow-ValidateAll-${var.environment}"
  rest_api_id                 = aws_api_gateway_rest_api.this.id
  validate_request_body       = false
  validate_request_parameters = true
}

resource "aws_api_gateway_method" "images_get" {
  rest_api_id          = aws_api_gateway_rest_api.this.id
  resource_id          = aws_api_gateway_resource.images.id
  http_method          = "GET"
  authorization        = var.cognito_user_pool_arn != null ? "COGNITO_USER_POOLS" : "NONE"
  authorizer_id        = var.cognito_user_pool_arn != null ? aws_api_gateway_authorizer.cognito[0].id : null
  request_validator_id = aws_api_gateway_request_validator.validate_all.id

  request_parameters = {
    "method.request.querystring.limit"  = false
    "method.request.querystring.status" = false
    "method.request.querystring.cursor" = false
  }
}

resource "aws_api_gateway_method" "images_item_get" {
  rest_api_id          = aws_api_gateway_rest_api.this.id
  resource_id          = aws_api_gateway_resource.images_item.id
  http_method          = "GET"
  authorization        = var.cognito_user_pool_arn != null ? "COGNITO_USER_POOLS" : "NONE"
  authorizer_id        = var.cognito_user_pool_arn != null ? aws_api_gateway_authorizer.cognito[0].id : null
  request_validator_id = aws_api_gateway_request_validator.validate_all.id

  request_parameters = {
    "method.request.path.image_id" = true
  }
}

resource "aws_api_gateway_method" "health_get" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.health.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "images_get" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.images.id
  http_method             = aws_api_gateway_method.images_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arn
}

resource "aws_api_gateway_integration" "images_item_get" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.images_item.id
  http_method             = aws_api_gateway_method.images_item_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arn
}

resource "aws_api_gateway_integration" "health_get" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.health.id
  http_method             = aws_api_gateway_method.health_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arn
}

resource "aws_api_gateway_deployment" "this" {
  depends_on = [
    aws_api_gateway_integration.images_get,
    aws_api_gateway_integration.images_item_get,
    aws_api_gateway_integration.health_get,
  ]
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = var.environment

  stage_description = "Deployed at ${timestamp()}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "this" {
  stage_name    = var.environment
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id

  access_log_settings {
    destination_arn = "${var.cloudwatch_log_group_arn}:*"
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled        = true
    logging_level          = "INFO"
    data_trace_enabled     = false
    throttling_rate_limit  = var.environment == "prod" ? 10000 : 1000
    throttling_burst_limit = var.environment == "prod" ? 5000 : 500
  }
}

resource "aws_api_gateway_usage_plan" "this" {
  name = "ImageFlow-UsagePlan-${var.environment}"

  api_stages {
    api_id = aws_api_gateway_rest_api.this.id
    stage  = aws_api_gateway_stage.this.stage_name
  }

  quota_settings {
    limit  = var.environment == "prod" ? 1000000 : 100000
    period = "MONTH"
  }

  throttle_settings {
    burst_limit = var.environment == "prod" ? 500 : 100
    rate_limit  = var.environment == "prod" ? 1000 : 200
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_api_gateway_api_key" "this" {
  name = "ImageFlow-APIKey-${var.environment}"
}

resource "aws_api_gateway_usage_plan_key" "this" {
  key_id        = aws_api_gateway_api_key.this.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.this.id
}

resource "aws_api_gateway_authorizer" "cognito" {
  count         = var.cognito_user_pool_arn != null ? 1 : 0
  name          = "ImageFlow-Cognito-${var.environment}"
  type          = "COGNITO_USER_POOLS"
  rest_api_id   = aws_api_gateway_rest_api.this.id
  provider_arns = [var.cognito_user_pool_arn]
}
