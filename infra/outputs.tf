output "deploy_role_arn" {
  description = "Set as GitHub Actions repo variable AWS_DEPLOY_ROLE_ARN."
  value       = aws_iam_role.deploy.arn
}

output "cloudfront_distribution_id" {
  description = "Set as GitHub Actions repo variable CLOUDFRONT_DISTRIBUTION_ID."
  value       = aws_cloudfront_distribution.site.id
}

output "cloudfront_domain_name" {
  description = "Use this for staging (raw CF URL) before DNS cutover."
  value       = aws_cloudfront_distribution.site.domain_name
}

output "route53_name_servers" {
  description = "Point the registrar's NS records at these four values for the cutover."
  value       = aws_route53_zone.site.name_servers
}

output "s3_bucket" {
  value = aws_s3_bucket.site.bucket
}
