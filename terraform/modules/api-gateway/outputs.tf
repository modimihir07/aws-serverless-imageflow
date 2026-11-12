output "api_id" {
  value = aws_api_gateway_rest_api.this.id
}

output "api_arn" {
  value = aws_api_gateway_rest_api.this.arn
}

output "execution_arn" {
  value = aws_api_gateway_rest_api.this.execution_arn
}

output "api_url" {
  value = "https://${aws_api_gateway_rest_api.this.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${var.environment}"
}

output "api_key" {
  value     = aws_api_gateway_api_key.this.value
  sensitive = true
}

data "aws_region" "current" {}
