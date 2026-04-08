output "sns_topic_arn" {
  description = "ARN of the SNS topic for alarm notifications"
  value       = try(aws_sns_topic.alarms[0].arn, null)
}

output "sns_topic_name" {
  description = "Name of the SNS topic for alarm notifications"
  value       = try(aws_sns_topic.alarms[0].name, null)
}

output "ecs_cpu_alarm_names" {
  description = "ECS CPU alarm names by service key"
  value       = { for k, a in aws_cloudwatch_metric_alarm.ecs_cpu : k => a.alarm_name }
}

output "ecs_memory_alarm_names" {
  description = "ECS memory alarm names by service key"
  value       = { for k, a in aws_cloudwatch_metric_alarm.ecs_memory : k => a.alarm_name }
}

output "alb_4xx_alarm_names" {
  description = "ALB 4xx alarm names"
  value       = { for k, a in aws_cloudwatch_metric_alarm.alb_4xx : k => a.alarm_name }
}

output "alb_5xx_alarm_names" {
  description = "ALB 5xx alarm names"
  value       = { for k, a in aws_cloudwatch_metric_alarm.alb_5xx : k => a.alarm_name }
}

output "alb_latency_alarm_names" {
  description = "ALB latency alarm names"
  value       = { for k, a in aws_cloudwatch_metric_alarm.alb_latency : k => a.alarm_name }
}

output "rds_cpu_alarm_names" {
  description = "RDS CPU alarm names"
  value       = { for k, a in aws_cloudwatch_metric_alarm.rds_cpu : k => a.alarm_name }
}

output "rds_connections_alarm_names" {
  description = "RDS connection alarm names"
  value       = { for k, a in aws_cloudwatch_metric_alarm.rds_connections : k => a.alarm_name }
}

output "rds_free_storage_alarm_names" {
  description = "RDS free storage alarm names"
  value       = { for k, a in aws_cloudwatch_metric_alarm.rds_free_storage : k => a.alarm_name }
}

output "unified_dashboard_name" {
  description = "CloudWatch dashboard (ECS + ALB + RDS)"
  value       = try(aws_cloudwatch_dashboard.unified[0].dashboard_name, null)
}

output "application_log_group_name" {
  description = "Application CloudWatch Logs group"
  value       = try(aws_cloudwatch_log_group.application_logs[0].name, null)
}

output "monitoring_summary" {
  description = "Summary of monitoring resources"
  value = {
    alarms_enabled        = var.enable_sns_notifications
    sns_topic_arn         = try(aws_sns_topic.alarms[0].arn, null)
    ecs_alarm_groups      = length(aws_cloudwatch_metric_alarm.ecs_cpu) + length(aws_cloudwatch_metric_alarm.ecs_memory)
    alb_alarm_groups      = length(aws_cloudwatch_metric_alarm.alb_4xx) + length(aws_cloudwatch_metric_alarm.alb_5xx) + length(aws_cloudwatch_metric_alarm.alb_latency)
    rds_alarm_groups      = length(aws_cloudwatch_metric_alarm.rds_cpu) + length(aws_cloudwatch_metric_alarm.rds_connections) + length(aws_cloudwatch_metric_alarm.rds_free_storage)
    dashboard_enabled     = local.has_dashboard
    log_aggregation_enabled = var.enable_log_group_aggregation
  }
}
