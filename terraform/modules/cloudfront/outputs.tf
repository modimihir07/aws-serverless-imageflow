output "frontend_distribution_id" {
  value = aws_cloudfront_distribution.frontend.id
}

output "frontend_distribution_domain" {
  value = aws_cloudfront_distribution.frontend.domain_name
}

output "frontend_oac_arn" {
  value = aws_cloudfront_origin_access_control.frontend.arn
}

output "images_distribution_id" {
  value = aws_cloudfront_distribution.images.id
}

output "images_distribution_domain" {
  value = aws_cloudfront_distribution.images.domain_name
}

output "images_oai_path" {
  value = aws_cloudfront_origin_access_identity.images.cloudfront_access_identity_path
}

output "security_headers_policy_id" {
  value = aws_cloudfront_response_headers_policy.security.id
}
