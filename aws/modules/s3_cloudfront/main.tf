data "aws_caller_identity" "current" {}

# S3 Content Bucket
resource "aws_s3_bucket" "content" {
  bucket = var.bucket_name
  tags   = var.tags
}

# Block public access
resource "aws_s3_bucket_public_access_block" "content" {
  bucket = aws_s3_bucket.content.id

  block_public_acls       = var.block_public_acls
  block_public_policy     = var.block_public_policy
  ignore_public_acls      = var.ignore_public_acls
  restrict_public_buckets = var.restrict_public_buckets
}

# Versioning
resource "aws_s3_bucket_versioning" "content" {
  bucket = aws_s3_bucket.content.id

  versioning_configuration {
    status     = var.enable_versioning ? "Enabled" : "Suspended"
    mfa_delete = var.enable_mfa_delete && var.enable_versioning ? "Enabled" : "Disabled"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "content" {
  count  = var.enable_encryption ? 1 : 0
  bucket = aws_s3_bucket.content.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn
    }
  }
}

# Access-log bucket (must exist before server access logging on content bucket)
resource "aws_s3_bucket" "access_logs" {
  count  = var.enable_logging && var.log_bucket_name != null ? 1 : 0
  bucket = var.log_bucket_name
  tags   = merge(var.tags, { Purpose = "s3-server-access-logs" })
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  count  = var.enable_logging && var.log_bucket_name != null ? 1 : 0
  bucket = aws_s3_bucket.access_logs[0].id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "access_logs" {
  count  = var.enable_logging && var.log_bucket_name != null ? 1 : 0
  bucket = aws_s3_bucket.access_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ServerAccessLogs"
        Effect = "Allow"
        Principal = {
          Service = "logging.s3.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.access_logs[0].arn}/s3-access-logs/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnLike = {
            "aws:SourceArn" = aws_s3_bucket.content.arn
          }
        }
      },
      {
        Sid    = "S3ServerAccessLogsAcl"
        Effect = "Allow"
        Principal = {
          Service = "logging.s3.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.access_logs[0].arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# Logging (after log bucket + policy exist)
resource "aws_s3_bucket_logging" "content" {
  count  = var.enable_logging && var.log_bucket_name != null ? 1 : 0
  bucket = aws_s3_bucket.content.id

  target_bucket = aws_s3_bucket.access_logs[0].id
  target_prefix = "s3-access-logs/"

  depends_on = [aws_s3_bucket_policy.access_logs]
}

# CORS
resource "aws_s3_bucket_cors_configuration" "content" {
  count  = length(var.cors_rules) > 0 ? 1 : 0
  bucket = aws_s3_bucket.content.id

  dynamic "cors_rule" {
    for_each = var.cors_rules
    content {
      allowed_headers = cors_rule.value.allowed_headers
      allowed_methods = cors_rule.value.allowed_methods
      allowed_origins = cors_rule.value.allowed_origins
      expose_headers  = cors_rule.value.expose_headers
      max_age_seconds = cors_rule.value.max_age_seconds
    }
  }
}

# Lifecycle rules
resource "aws_s3_bucket_lifecycle_configuration" "content" {
  count  = length(var.lifecycle_rules) > 0 ? 1 : 0
  bucket = aws_s3_bucket.content.id

  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      id     = rule.value.id
      status = rule.value.enabled ? "Enabled" : "Disabled"

      dynamic "filter" {
        for_each = rule.value.prefix != null && rule.value.prefix != "" ? [1] : []
        content {
          prefix = rule.value.prefix
        }
      }

      dynamic "expiration" {
        for_each = rule.value.expiration_days != null ? [1] : []
        content {
          days = rule.value.expiration_days
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = rule.value.noncurrent_expiration_days != null ? [1] : []
        content {
          noncurrent_days = rule.value.noncurrent_expiration_days
        }
      }

      dynamic "transition" {
        for_each = rule.value.transition_storage_class != null ? [1] : []
        content {
          days          = rule.value.transition_days
          storage_class = rule.value.transition_storage_class
        }
      }

      dynamic "noncurrent_version_transition" {
        for_each = rule.value.noncurrent_version_transition_storage_class != null ? [1] : []
        content {
          noncurrent_days = rule.value.noncurrent_version_transition_days
          storage_class   = rule.value.noncurrent_version_transition_storage_class
        }
      }
    }
  }
}

# CloudFront Origin Access Identity
resource "aws_cloudfront_origin_access_identity" "s3_oai" {
  count   = var.enable_cloudfront ? 1 : 0
  comment = "OAI for ${var.bucket_name}"
}

# S3 bucket policy for CloudFront
resource "aws_s3_bucket_policy" "cloudfront_access" {
  count  = var.enable_cloudfront ? 1 : 0
  bucket = aws_s3_bucket.content.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudFrontAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.s3_oai[0].iam_arn
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.content.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.content]
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "s3_distribution" {
  count           = var.enable_cloudfront ? 1 : 0
  enabled         = true
  is_ipv6_enabled = true
  comment         = "CloudFront distribution for ${var.bucket_name}"
  price_class     = var.cloudfront_price_class

  origin {
    domain_name = aws_s3_bucket.content.bucket_regional_domain_name
    origin_id   = "S3Origin"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.s3_oai[0].cloudfront_access_identity_path
    }
  }

  default_cache_behavior {
    allowed_methods  = var.cloudfront_allowed_methods
    cached_methods   = var.cloudfront_cached_methods
    target_origin_id = "S3Origin"
    compress         = var.cloudfront_compress

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    default_ttl            = var.cloudfront_default_ttl
    max_ttl                = var.cloudfront_max_ttl
    min_ttl                = var.cloudfront_min_ttl
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.cloudfront_custom_domain == null ? true : false
    acm_certificate_arn            = var.cloudfront_custom_domain != null ? var.cloudfront_acm_certificate_arn : null
    ssl_support_method             = var.cloudfront_custom_domain != null ? "sni-only" : null
    minimum_protocol_version       = var.cloudfront_custom_domain != null ? "TLSv1.2_2021" : null
  }

  aliases = var.cloudfront_custom_domain != null ? [var.cloudfront_custom_domain] : []

  tags = var.tags
}
