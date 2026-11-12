output "image_processor_function_name" {
  value = aws_lambda_function.image_processor.function_name
}

output "image_processor_function_arn" {
  value = aws_lambda_function.image_processor.arn
}

output "image_api_function_name" {
  value = aws_lambda_function.image_api.function_name
}

output "image_api_function_arn" {
  value = aws_lambda_function.image_api.arn
}

output "dlq_queue_url" {
  value = aws_sqs_queue.dlq.id
}

output "dlq_queue_arn" {
  value = aws_sqs_queue.dlq.arn
}

output "dlq_alarm_name" {
  value = aws_cloudwatch_metric_alarm.dlq_alarm.alarm_name
}
