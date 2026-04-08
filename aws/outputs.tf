# ─── VPC ──────────────────────────────────────────────────────────────────────

output "vpc_id" {
  value = try(module.vpc[0].vpc_id, null)
}

output "vpc_public_subnets" {
  value = try(module.vpc[0].public_subnets, null)
}

output "vpc_private_subnets" {
  value = try(module.vpc[0].private_subnets, null)
}

# ─── ECR ──────────────────────────────────────────────────────────────────────

output "ecr_repository_urls" {
  description = "ECR URLs for docker push (api, admin, customer)"
  value       = { for k, v in module.ecr : k => v.repository_url }
}

# ─── Secrets ──────────────────────────────────────────────────────────────────

output "secret_arns" {
  value = { for k, v in module.secrets : k => v.secret_arn }
}

# ─── S3 + CloudFront ─────────────────────────────────────────────────────────

output "s3_bucket_name" {
  value = try(module.s3_cloudfront[0].bucket_name, null)
}

output "cloudfront_domain" {
  value = try(module.s3_cloudfront[0].cloudfront_domain_name, null)
}

# ─── ACM ──────────────────────────────────────────────────────────────────────

output "acm_certificate_arn" {
  value = aws_acm_certificate.main.arn
}

# ─── ALB ──────────────────────────────────────────────────────────────────────

output "alb_dns_name" {
  description = "ALB DNS name — point your domain CNAME here"
  value       = module.alb.dns_name
}

output "alb_zone_id" {
  value = module.alb.zone_id
}

# ─── RDS ──────────────────────────────────────────────────────────────────────

output "rds_endpoint" {
  description = "RDS endpoint (host:port)"
  value       = module.rds.endpoint
}

output "rds_address" {
  description = "RDS hostname"
  value       = module.rds.address
  sensitive   = true
}

# ─── ECS ──────────────────────────────────────────────────────────────────────

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "ecs_service_names" {
  value = module.ecs.service_names
}

# ─── Cost budget ──────────────────────────────────────────────────────────────

output "cost_budget_name" {
  description = "AWS Budget name (when cost_budget.enabled)"
  value       = try(module.cost_budget[0].budget_name, null)
}

# ─── Monitoring ───────────────────────────────────────────────────────────────

output "monitoring_sns_topic_arn" {
  value = try(module.monitoring[0].sns_topic_arn, null)
}

output "monitoring_dashboard_name" {
  value = try(module.monitoring[0].unified_dashboard_name, null)
}

# ─── Deployment info ──────────────────────────────────────────────────────────

output "deploy_commands" {
  description = "Handy commands after first apply"
  value = <<-EOT
    # Login to ECR:
    aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com

    # Force new deployment after pushing images:
    aws ecs update-service --cluster ${module.ecs.cluster_name} --service api --force-new-deployment
    aws ecs update-service --cluster ${module.ecs.cluster_name} --service customer --force-new-deployment
    aws ecs update-service --cluster ${module.ecs.cluster_name} --service admin --force-new-deployment
  EOT
}
