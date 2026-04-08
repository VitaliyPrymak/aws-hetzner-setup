data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ═════════════════════════════════════════════════════════════════════════════
# VPC — public/private subnets, IGW, route tables
# ═════════════════════════════════════════════════════════════════════════════

module "vpc" {
  count  = try(var.vpc_network.enabled, true) ? 1 : 0
  source = "./modules/vpc"

  name       = "${var.project_name}-${var.environment}"
  cidr_block = coalesce(try(var.vpc_network.cidr_block, null), "10.0.0.0/16")
  azs        = coalesce(try(var.vpc_network.azs, null), ["eu-central-1a", "eu-central-1b"])
  public_subnets = coalesce(try(var.vpc_network.public_subnets, null), [
    "10.0.101.0/24", "10.0.102.0/24"
  ])
  private_subnets = coalesce(try(var.vpc_network.private_subnets, null), [
    "10.0.1.0/24", "10.0.2.0/24"
  ])
  enable_nat_gateway = coalesce(try(var.vpc_network.enable_nat_gateway, null), false)
  enable_vpn_gateway = coalesce(try(var.vpc_network.enable_vpn_gateway, null), false)

  tags = var.tags
}

module "vpc_endpoints" {
  count  = try(var.vpc_endpoints.enabled, false) && try(var.vpc_network.enabled, true) ? 1 : 0
  source = "./modules/vpc-endpoints"

  vpc_id     = module.vpc[0].vpc_id
  subnet_ids = coalesce(try(var.vpc_endpoints.subnet_ids, null), module.vpc[0].private_subnets)
  endpoints  = try(var.vpc_endpoints.endpoints, {})

  tags = var.tags
}

# ═════════════════════════════════════════════════════════════════════════════
# ECR — Docker image repositories
# ═════════════════════════════════════════════════════════════════════════════

module "ecr" {
  for_each = var.ecr_repositories
  source   = "./modules/ecr"

  repository_name        = each.value.name
  image_tag_mutability   = each.value.image_tag_mutability
  scan_on_push           = each.value.scan_on_push
  lifecycle_policy_count = each.value.lifecycle_policy_count
  encryption_type        = each.value.encryption_type
  kms_key_arn            = try(each.value.kms_key_arn, null)
  allowed_account_ids    = try(each.value.allowed_account_ids, [])
  force_delete           = try(each.value.force_delete, true)

  tags = merge(var.tags, { Module = "ecr", Service = each.key })
}

# ═════════════════════════════════════════════════════════════════════════════
# Secrets Manager — application secrets (except db-url which depends on RDS)
# ═════════════════════════════════════════════════════════════════════════════

module "secrets" {
  for_each = toset(nonsensitive(keys(var.secrets)))
  source   = "./modules/secrets"

  secret_name          = "${each.value}-${var.environment}"
  secret_string        = var.secrets[each.value].secret_string
  description          = var.secrets[each.value].description
  recovery_window_days = var.secrets[each.value].recovery_window_days

  tags = merge(var.tags, { Module = "secrets", Name = each.value })
}

# ═════════════════════════════════════════════════════════════════════════════
# S3 + CloudFront — static asset storage and CDN
# ═════════════════════════════════════════════════════════════════════════════

module "s3_cloudfront" {
  count  = var.enable_s3_cloudfront && var.s3_bucket_name != null ? 1 : 0
  source = "./modules/s3_cloudfront"

  bucket_name       = var.s3_bucket_name
  enable_versioning = var.environment == "prod"
  enable_logging    = var.environment == "prod"
  log_bucket_name   = var.environment == "prod" ? "${var.s3_bucket_name}-logs" : null

  enable_cloudfront          = true
  cloudfront_price_class     = var.cloudfront_price_class
  cloudfront_compress        = true
  cloudfront_allowed_methods = ["GET", "HEAD"]
  cloudfront_cached_methods  = ["GET", "HEAD"]

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  enable_encryption       = true

  tags = merge(var.tags, { Module = "s3_cloudfront" })
}

# ═════════════════════════════════════════════════════════════════════════════
# ACM Certificate — TLS for ALB (root + wildcard SAN)
# ═════════════════════════════════════════════════════════════════════════════

resource "aws_acm_certificate" "main" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  tags = merge(var.tags, { Name = var.domain_name })

  lifecycle { create_before_destroy = true }
}

# ═════════════════════════════════════════════════════════════════════════════
# Cloudflare DNS — ACM validation + domain → ALB
# ═════════════════════════════════════════════════════════════════════════════

data "cloudflare_zone" "main" {
  name = var.domain_name
}

# One Cloudflare CNAME per unique ACM validation FQDN (root + wildcard often share one name).
locals {
  acm_validation_fqdns = toset([
    for dvo in aws_acm_certificate.main.domain_validation_options :
    trimsuffix(dvo.resource_record_name, ".")
  ])
}

resource "cloudflare_record" "acm_validation" {
  for_each = local.acm_validation_fqdns

  zone_id         = data.cloudflare_zone.main.id
  allow_overwrite = true
  proxied         = false
  ttl             = 120

  name = replace(each.key, ".${var.domain_name}", "")
  type = one(distinct([
    for dvo in aws_acm_certificate.main.domain_validation_options :
    dvo.resource_record_type
    if trimsuffix(dvo.resource_record_name, ".") == each.key
  ]))
  content = trimsuffix(one(distinct([
    for dvo in aws_acm_certificate.main.domain_validation_options :
    dvo.resource_record_value
    if trimsuffix(dvo.resource_record_name, ".") == each.key
  ])), ".")
}

resource "aws_acm_certificate_validation" "main" {
  certificate_arn = aws_acm_certificate.main.arn
  validation_record_fqdns = distinct([
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.resource_record_name
  ])
}

# ═════════════════════════════════════════════════════════════════════════════
# ALB — HTTPS load balancer with path/host routing
#   /api/*                → api target group (port 8080)
#   admin.example.com → admin target group (port 80)
#   default (everything)   → customer target group (port 3000)
# ═════════════════════════════════════════════════════════════════════════════

module "alb" {
  source = "./modules/alb"

  name            = "${var.project_name}-${var.environment}"
  vpc_id          = module.vpc[0].vpc_id
  subnet_ids      = module.vpc[0].public_subnets
  certificate_arn = aws_acm_certificate_validation.main.certificate_arn

  hosts = { admin = "admin.${var.domain_name}" }

  target_ports       = var.target_ports
  health_check_paths = var.health_check_paths
  api_path_patterns  = ["/api/*"]

  tags = var.tags
}

# Domain CNAME → ALB (proxied through Cloudflare)
resource "cloudflare_record" "root" {
  zone_id = data.cloudflare_zone.main.id
  name    = "@"
  type    = "CNAME"
  content = module.alb.dns_name
  ttl     = 1
  proxied = true
}

resource "cloudflare_record" "admin" {
  zone_id = data.cloudflare_zone.main.id
  name    = "admin"
  type    = "CNAME"
  content = module.alb.dns_name
  ttl     = 1
  proxied = true
}

# ═════════════════════════════════════════════════════════════════════════════
# RDS PostgreSQL — private subnets, accessible only from ECS
# ═════════════════════════════════════════════════════════════════════════════

module "rds" {
  source = "./modules/rds"

  identifier                = "${var.project_name}-${var.environment}"
  vpc_id                    = module.vpc[0].vpc_id
  subnet_ids                = module.vpc[0].private_subnets
  allowed_security_groups = { ecs = module.ecs.security_group_id }

  engine_version          = var.rds_config.engine_version
  instance_class          = var.rds_config.instance_class
  allocated_storage       = var.rds_config.allocated_storage
  max_allocated_storage   = var.rds_config.max_allocated_storage
  db_name                 = var.rds_config.db_name
  db_username             = var.rds_config.db_username
  db_password             = var.rds_config.db_password
  multi_az                = var.rds_config.multi_az
  backup_retention_period = var.rds_config.backup_retention_period
  skip_final_snapshot     = var.environment == "dev"
  deletion_protection     = var.environment == "prod"

  tags = merge(var.tags, { Module = "rds" })
}

# DB URL secret — constructed from RDS endpoint after it's created
resource "aws_secretsmanager_secret" "db_url" {
  name                    = "db-url-${var.environment}"
  description             = "PostgreSQL connection string for ${var.project_name}"
  recovery_window_in_days = 7
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "db_url" {
  secret_id     = aws_secretsmanager_secret.db_url.id
  secret_string = "postgres://${var.rds_config.db_username}:${var.rds_config.db_password}@${module.rds.address}:5432/${var.rds_config.db_name}?sslmode=require"
}

# ═════════════════════════════════════════════════════════════════════════════
# ECS Fargate — 3 services (api, customer, admin)
# ═════════════════════════════════════════════════════════════════════════════

locals {
  ecr_urls = { for k, v in module.ecr : k => v.repository_url }
}

module "ecs" {
  source = "./modules/ecs"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  vpc_id                = module.vpc[0].vpc_id
  subnet_ids            = module.vpc[0].public_subnets
  alb_security_group_id = module.alb.security_group_id

  enable_s3_access = var.enable_s3_cloudfront
  s3_bucket_arn    = try(module.s3_cloudfront[0].bucket_arn, null)
  enable_ses_access = true

  services = {
    api = {
      image          = "${local.ecr_urls["api"]}:latest"
      cpu            = var.ecs_services.api.cpu
      memory         = var.ecs_services.api.memory
      container_port = var.ecs_services.api.port
      desired_count  = var.ecs_services.api.desired_count
      target_group_arn = module.alb.target_groups["api"].arn

      environment = {
        APP_ENV               = var.environment == "prod" ? "production" : "development"
        PORT                  = tostring(var.ecs_services.api.port)
        MIGRATIONS_LOCATION   = "/app/migrations"
        ALLOWED_CORS_ORIGINS  = "https://${var.domain_name},https://admin.${var.domain_name}"
        MONOPAY_MERCHANT_ID   = var.api_env.monopay_merchant_id
        MONOPAY_CALLBACK_URL  = "https://${var.domain_name}/api/webhook/monobank/payment"
        MONOPAY_REDIRECT_URL  = "https://${var.domain_name}"
        AWS_REGION            = var.aws_region
        AWS_SMTP_SENDER_EMAIL = var.api_env.aws_smtp_sender_email
        AWS_BUCKET_NAME       = try(module.s3_cloudfront[0].bucket_name, var.api_env.aws_bucket_name)
      }

      secrets = {
        DB_URL                 = aws_secretsmanager_secret.db_url.arn
        SECRET_TOKEN           = module.secrets["secret-token"].secret_arn
        MONOPAY_API_KEY        = module.secrets["monopay-api-key"].secret_arn
        MONOPAY_WEBHOOK_SECRET = module.secrets["monopay-webhook-secret"].secret_arn
        TELEGRAM_BOT_TOKEN     = module.secrets["telegram-bot-token"].secret_arn
        AWS_ACCESS_KEY         = module.secrets["aws-access-key"].secret_arn
        AWS_SECRET_ACCESS_KEY  = module.secrets["aws-secret-access-key"].secret_arn
      }

      health_check = {
        command     = ["CMD-SHELL", "wget -qO- http://localhost:8080/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }

    customer = {
      image          = "${local.ecr_urls["customer"]}:latest"
      cpu            = var.ecs_services.customer.cpu
      memory         = var.ecs_services.customer.memory
      container_port = var.ecs_services.customer.port
      desired_count  = var.ecs_services.customer.desired_count
      target_group_arn = module.alb.target_groups["customer"].arn

      environment = {
        NUXT_PUBLIC_API_BASE = "https://${var.domain_name}/api"
        NODE_ENV             = "production"
      }
      secrets = {}
    }

    admin = {
      image          = "${local.ecr_urls["admin"]}:latest"
      cpu            = var.ecs_services.admin.cpu
      memory         = var.ecs_services.admin.memory
      container_port = var.ecs_services.admin.port
      desired_count  = var.ecs_services.admin.desired_count
      target_group_arn = module.alb.target_groups["admin"].arn

      environment = {}
      secrets     = {}
    }
  }

  tags = merge(var.tags, { Module = "ecs" })
}

# ═════════════════════════════════════════════════════════════════════════════
# Cost budget — monthly USD cap + email (AWS Budgets)
# ═════════════════════════════════════════════════════════════════════════════

module "cost_budget" {
  count = try(var.cost_budget.enabled, false) && length(try(var.cost_budget.notification_emails, [])) > 0 ? 1 : 0

  source = "./modules/budget"

  name                = "${var.project_name}-${var.environment}-monthly-usd"
  monthly_limit_usd   = try(var.cost_budget.monthly_limit_usd, 90)
  time_period_start   = try(var.cost_budget.time_period_start, "2026-01-01_00:00")
  notification_emails = var.cost_budget.notification_emails
  tags                = var.tags
}

# ═════════════════════════════════════════════════════════════════════════════
# Monitoring — CloudWatch dashboards + alarms (enable after first deploy)
# ═════════════════════════════════════════════════════════════════════════════

module "monitoring" {
  count  = var.monitoring.enabled ? 1 : 0
  source = "./modules/monitoring"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  ecs_services       = var.monitoring.ecs_services
  alb_load_balancers = var.monitoring.alb_load_balancers
  rds_instance_ids   = var.monitoring.rds_instance_ids

  sns_email                    = var.monitoring.sns_email
  enable_sns_notifications     = var.monitoring.enable_sns_notifications
  enable_log_group_aggregation = var.monitoring.enable_log_group_aggregation
  log_retention_days           = var.monitoring.log_retention_days

  tags = var.tags
}
