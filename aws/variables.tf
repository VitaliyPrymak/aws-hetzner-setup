# ─── General ──────────────────────────────────────────────────────────────────

variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be dev or prod."
  }
}

variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "project_name" {
  type    = string
  default = "myapp"
}

variable "domain_name" {
  description = "Root domain (Cloudflare zone must exist). ACM cert covers *.domain."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

# ─── ECR ──────────────────────────────────────────────────────────────────────

variable "ecr_repositories" {
  type = map(object({
    name                   = string
    image_tag_mutability   = optional(string, "MUTABLE")
    scan_on_push           = optional(bool, false)
    lifecycle_policy_count = optional(number, 10)
    encryption_type        = optional(string, "AES256")
    kms_key_arn            = optional(string, null)
    allowed_account_ids    = optional(list(string), [])
    force_delete           = optional(bool, true)
  }))
  default = {}
}

# ─── Secrets ──────────────────────────────────────────────────────────────────

variable "secrets" {
  description = "Secrets for Secrets Manager (db-url is auto-created from RDS)"
  type = map(object({
    secret_string        = string
    description          = optional(string, "")
    recovery_window_days = optional(number, 7)
  }))
  default   = {}
  sensitive = true
}

# ─── S3 + CloudFront ─────────────────────────────────────────────────────────

variable "enable_s3_cloudfront" {
  type    = bool
  default = false
}

variable "s3_bucket_name" {
  type    = string
  default = null
}

variable "cloudfront_price_class" {
  type    = string
  default = "PriceClass_100"
}

# ─── RDS ──────────────────────────────────────────────────────────────────────

variable "rds_config" {
  type = object({
    engine_version          = optional(string, "16.6")
    instance_class          = optional(string, "db.t4g.micro")
    allocated_storage       = optional(number, 20)
    max_allocated_storage   = optional(number, 50)
    db_name                 = string
    db_username             = string
    db_password             = string
    multi_az                = optional(bool, false)
    backup_retention_period = optional(number, 7)
  })
  sensitive = true
}

# ─── ECS Services ─────────────────────────────────────────────────────────────

variable "ecs_services" {
  description = "CPU/memory/port/count per service"
  type = object({
    api = object({
      cpu           = optional(number, 512)
      memory        = optional(number, 1024)
      port          = optional(number, 8080)
      desired_count = optional(number, 1)
    })
    customer = object({
      cpu           = optional(number, 256)
      memory        = optional(number, 512)
      port          = optional(number, 3000)
      desired_count = optional(number, 1)
    })
    admin = object({
      cpu           = optional(number, 256)
      memory        = optional(number, 512)
      port          = optional(number, 80)
      desired_count = optional(number, 1)
    })
  })
  default = {
    api      = {}
    customer = {}
    admin    = {}
  }
}

variable "api_env" {
  description = "Non-sensitive environment variables for the API service"
  type = object({
    monopay_merchant_id   = optional(string, "changeme")
    aws_smtp_sender_email = optional(string, "changeme@example.com")
    aws_bucket_name       = optional(string, "changeme")
  })
  default = {}
}

# ─── ALB ──────────────────────────────────────────────────────────────────────

variable "target_ports" {
  type = object({
    customer = number
    api      = number
    admin    = number
  })
  default = {
    customer = 3000
    api      = 8080
    admin    = 80
  }
}

variable "health_check_paths" {
  type = object({
    customer = string
    api      = string
    admin    = string
  })
  default = {
    customer = "/"
    api      = "/health"
    admin    = "/"
  }
}

# ─── VPC ──────────────────────────────────────────────────────────────────────

variable "vpc_network" {
  type = object({
    enabled            = optional(bool, true)
    cidr_block         = optional(string, "10.0.0.0/16")
    azs                = optional(list(string), ["eu-central-1a", "eu-central-1b"])
    public_subnets     = optional(list(string), ["10.0.101.0/24", "10.0.102.0/24"])
    private_subnets    = optional(list(string), ["10.0.1.0/24", "10.0.2.0/24"])
    enable_nat_gateway = optional(bool, false)
    enable_vpn_gateway = optional(bool, false)
  })
  default = {}
}

variable "vpc_endpoints" {
  type = object({
    enabled    = optional(bool, false)
    endpoints  = optional(any, {})
    subnet_ids = optional(list(string))
  })
  default = {}
}

# ─── Cost budget (AWS Budgets) ────────────────────────────────────────────────

variable "cost_budget" {
  description = "Monthly AWS cost budget and email alerts (confirm subscription on first email from AWS)"
  type = object({
    enabled             = optional(bool, false)
    monthly_limit_usd   = optional(number, 90)
    notification_emails = optional(list(string), [])
    time_period_start   = optional(string, "2026-01-01_00:00")
  })
  default = {}
}

# ─── Monitoring ───────────────────────────────────────────────────────────────

variable "monitoring" {
  description = "Enable after first successful deploy; fill maps with real resource names."
  type = object({
    enabled                      = optional(bool, false)
    ecs_services                 = optional(map(object({ cluster_name = string, service_name = string })), {})
    alb_load_balancers           = optional(map(string), {})
    rds_instance_ids             = optional(map(string), {})
    sns_email                    = optional(string, "")
    enable_sns_notifications     = optional(bool, true)
    enable_log_group_aggregation = optional(bool, true)
    log_retention_days           = optional(number, 14)
  })
  default = {}
}
