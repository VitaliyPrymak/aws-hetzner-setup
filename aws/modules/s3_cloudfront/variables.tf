variable "bucket_name" {
  description = "Name of the S3 bucket for content storage"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Bucket name must be 3-63 characters, start/end with lowercase alphanumeric, contain only lowercase letters, numbers, and hyphens."
  }
}

variable "enable_versioning" {
  description = "Enable S3 versioning for backup and recovery"
  type        = bool
  default     = false
}

variable "enable_mfa_delete" {
  description = "Enable MFA delete protection (requires versioning enabled)"
  type        = bool
  default     = false
}

variable "enable_logging" {
  description = "Enable S3 access logging"
  type        = bool
  default     = true
}

variable "log_bucket_name" {
  description = "Name of the bucket for storing access logs (if enable_logging=true)"
  type        = string
  default     = null
}

variable "enable_cloudfront" {
  description = "Enable CloudFront CDN distribution"
  type        = bool
  default     = true
}

variable "cloudfront_price_class" {
  description = "CloudFront price class (PriceClass_100, PriceClass_200, PriceClass_All)"
  type        = string
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.cloudfront_price_class)
    error_message = "CloudFront price class must be PriceClass_100, PriceClass_200, or PriceClass_All."
  }
}

variable "cloudfront_default_ttl" {
  description = "CloudFront default TTL in seconds"
  type        = number
  default     = 86400

  validation {
    condition     = var.cloudfront_default_ttl >= 0
    error_message = "CloudFront default TTL must be non-negative."
  }
}

variable "cloudfront_max_ttl" {
  description = "CloudFront maximum TTL in seconds"
  type        = number
  default     = 31536000

  validation {
    condition     = var.cloudfront_max_ttl >= 0
    error_message = "CloudFront max TTL must be non-negative."
  }
}

variable "cloudfront_min_ttl" {
  description = "CloudFront minimum TTL in seconds"
  type        = number
  default     = 0

  validation {
    condition     = var.cloudfront_min_ttl >= 0
    error_message = "CloudFront min TTL must be non-negative."
  }
}

variable "cloudfront_compress" {
  description = "Enable gzip compression in CloudFront"
  type        = bool
  default     = true
}

variable "cloudfront_allowed_methods" {
  description = "Allowed HTTP methods for CloudFront"
  type        = list(string)
  default     = ["GET", "HEAD"]

  validation {
    condition = alltrue([
      for method in var.cloudfront_allowed_methods : contains(["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"], method)
    ])
    error_message = "CloudFront allowed methods must be valid HTTP methods."
  }
}

variable "cloudfront_cached_methods" {
  description = "HTTP methods to cache in CloudFront"
  type        = list(string)
  default     = ["GET", "HEAD"]

  validation {
    condition = alltrue([
      for method in var.cloudfront_cached_methods : contains(["GET", "HEAD", "OPTIONS"], method)
    ])
    error_message = "CloudFront cached methods must be GET, HEAD, or OPTIONS."
  }
}

variable "enable_signed_urls" {
  description = "Enable CloudFront signed URLs for protected content"
  type        = bool
  default     = false
}

variable "cloudfront_custom_domain" {
  description = "Custom domain name for CloudFront distribution (e.g., cdn.example.com)"
  type        = string
  default     = null
}

variable "cloudfront_acm_certificate_arn" {
  description = "ARN of ACM certificate for custom domain (required if cloudfront_custom_domain is set)"
  type        = string
  default     = null
}

variable "block_public_acls" {
  description = "Block public ACLs on the bucket"
  type        = bool
  default     = true
}

variable "block_public_policy" {
  description = "Block public bucket policies"
  type        = bool
  default     = true
}

variable "ignore_public_acls" {
  description = "Ignore existing public ACLs"
  type        = bool
  default     = true
}

variable "restrict_public_buckets" {
  description = "Restrict public bucket access"
  type        = bool
  default     = true
}

variable "enable_encryption" {
  description = "Enable S3 server-side encryption"
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "KMS key ARN for S3 encryption (if blank, uses S3-managed keys)"
  type        = string
  default     = null
}

variable "cors_rules" {
  description = "CORS rules for the bucket"
  type = list(object({
    allowed_headers = list(string)
    allowed_methods = list(string)
    allowed_origins = list(string)
    expose_headers  = optional(list(string))
    max_age_seconds = optional(number, 3000)
  }))
  default = []
}

variable "lifecycle_rules" {
  description = "S3 lifecycle rules for object expiration and transitions"
  type = list(object({
    id      = string
    enabled = optional(bool, true)
    prefix  = optional(string, "")

    expiration_days            = optional(number)
    noncurrent_expiration_days = optional(number)

    transition_storage_class = optional(string)
    transition_days          = optional(number)

    noncurrent_version_transition_storage_class = optional(string)
    noncurrent_version_transition_days          = optional(number)
  }))
  default = []
}

variable "tags" {
  description = "AWS tags to apply to all resources"
  type        = map(string)
  default     = {}
}
