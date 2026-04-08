output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.content.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.content.arn
}

output "bucket_region" {
  description = "Region of the S3 bucket"
  value       = aws_s3_bucket.content.region
}

output "bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = aws_s3_bucket.content.bucket_domain_name
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name (if enabled)"
  value       = try(aws_cloudfront_distribution.s3_distribution[0].domain_name, null)
}

output "cloudfront_custom_domain" {
  description = "Custom domain name for CloudFront (if configured)"
  value       = var.cloudfront_custom_domain
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (if enabled)"
  value       = try(aws_cloudfront_distribution.s3_distribution[0].id, null)
}

output "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN (if enabled)"
  value       = try(aws_cloudfront_distribution.s3_distribution[0].arn, null)
}

output "cloudfront_origin_access_identity_arn" {
  description = "CloudFront OAI ARN (if enabled)"
  value       = try(aws_cloudfront_origin_access_identity.s3_oai[0].iam_arn, null)
}

output "cloudfront_origin_access_identity_path" {
  description = "CloudFront OAI path for S3 origin (if enabled)"
  value       = try(aws_cloudfront_origin_access_identity.s3_oai[0].cloudfront_access_identity_path, null)
}
