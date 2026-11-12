output "image_processor_role_arn" {
  value = aws_iam_role.image_processor.arn
}

output "image_processor_role_name" {
  value = aws_iam_role.image_processor.name
}

output "image_api_role_arn" {
  value = aws_iam_role.image_api.arn
}

output "image_api_role_name" {
  value = aws_iam_role.image_api.name
}

output "step_functions_role_arn" {
  value = aws_iam_role.step_functions.arn
}

output "api_gateway_cw_role_arn" {
  value = aws_iam_role.api_gateway_cloudwatch.arn
}
