terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# CloudFront and ACM certs for CloudFront must live in us-east-1.
provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}

locals {
  aliases = [var.domain, "www.${var.domain}"]
  tags = {
    Project = "offset-print"
    Managed = "terraform"
  }
}

# ---------------------------------------------------------------------------
# S3 — private bucket; CloudFront accesses via OAC.
# Versioning on, with lifecycle to expire non-current versions and abort
# multi-part uploads. Without lifecycle, deploy churn quietly grows storage.
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "site" {
  bucket = var.bucket_name
  tags   = local.tags
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "site" {
  bucket = aws_s3_bucket.site.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    id     = "expire-noncurrent"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# ---------------------------------------------------------------------------
# CloudFront Function — rewrite directory URLs (e.g. /about/ -> /about/index.html)
# ---------------------------------------------------------------------------

resource "aws_cloudfront_function" "rewrite" {
  name    = "offsetprint-rewrite"
  runtime = "cloudfront-js-2.0"
  comment = "Append index.html to directory-style URLs"
  publish = true
  code    = <<-JS
    function handler(event) {
      var req = event.request;
      var uri = req.uri;
      if (uri.endsWith('/')) {
        req.uri = uri + 'index.html';
      } else if (!uri.includes('.')) {
        req.uri = uri + '/index.html';
      }
      return req;
    }
  JS
}

# ---------------------------------------------------------------------------
# ACM cert in us-east-1 (CloudFront requirement). DNS validation via Route 53.
# ---------------------------------------------------------------------------

resource "aws_acm_certificate" "site" {
  provider                  = aws.use1
  domain_name               = var.domain
  subject_alternative_names = ["www.${var.domain}"]
  validation_method         = "DNS"
  tags                      = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.site.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.site.zone_id
}

resource "aws_acm_certificate_validation" "site" {
  provider                = aws.use1
  certificate_arn         = aws_acm_certificate.site.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# ---------------------------------------------------------------------------
# CloudFront distribution
# ---------------------------------------------------------------------------

resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "offsetprint-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# AWS-managed CachingOptimized policy
data "aws_cloudfront_cache_policy" "optimized" {
  name = "Managed-CachingOptimized"
}

# AWS-managed SecurityHeadersPolicy
data "aws_cloudfront_response_headers_policy" "security" {
  name = "Managed-SecurityHeadersPolicy"
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = "offsetprint.eu"
  aliases             = local.aliases
  http_version        = "http2and3"
  price_class         = "PriceClass_100" # NA + EU edges only

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "s3-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }

  default_cache_behavior {
    target_origin_id           = "s3-origin"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = data.aws_cloudfront_cache_policy.optimized.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.rewrite.arn
    }
  }

  # Static-site 404 — return a real 404 status, not 200.
  custom_error_response {
    error_code            = 403
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = 60
  }
  custom_error_response {
    error_code            = 404
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = 60
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.site.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = local.tags
}

# Allow CloudFront (via OAC) to read from the bucket.
data "aws_iam_policy_document" "bucket" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.site.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.bucket.json
}

# ---------------------------------------------------------------------------
# Route 53 — apex + www ALIAS to CloudFront.
# Add the existing email/MX records in route53_extra_records.tf (created
# by hand from the DNS audit, BEFORE switching nameservers).
# ---------------------------------------------------------------------------

resource "aws_route53_zone" "site" {
  name = var.domain
  tags = local.tags
}

resource "aws_route53_record" "apex" {
  zone_id = aws_route53_zone.site.zone_id
  name    = var.domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.site.zone_id
  name    = "www.${var.domain}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

# ---------------------------------------------------------------------------
# GitHub Actions OIDC — tightly scoped to one repo + branch.
# ---------------------------------------------------------------------------

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "github_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Pinned to one repo, one branch. Without this, any branch / fork PR
    # that runs the workflow could assume the role.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:ref:refs/heads/${var.github_branch}"]
    }
  }
}

resource "aws_iam_role" "deploy" {
  name               = "offsetprint-github-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_trust.json
  tags               = local.tags
}

data "aws_iam_policy_document" "deploy" {
  statement {
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [aws_s3_bucket.site.arn]
  }
  statement {
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.site.arn}/*"]
  }
  statement {
    actions   = ["cloudfront:CreateInvalidation"]
    resources = [aws_cloudfront_distribution.site.arn]
  }
}

resource "aws_iam_role_policy" "deploy" {
  role   = aws_iam_role.deploy.id
  name   = "deploy"
  policy = data.aws_iam_policy_document.deploy.json
}

# ---------------------------------------------------------------------------
# Cost guard.
# ---------------------------------------------------------------------------

resource "aws_budgets_budget" "monthly" {
  name              = "offsetprint-site-monthly"
  budget_type       = "COST"
  limit_amount      = "5"
  limit_unit        = "USD"
  time_unit         = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }
}
