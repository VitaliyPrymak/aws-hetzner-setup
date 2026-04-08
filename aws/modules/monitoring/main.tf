# SNS Topic for Alarms
resource "aws_sns_topic" "alarms" {
  count = var.enable_sns_notifications ? 1 : 0
  name  = var.sns_topic_name != "" ? var.sns_topic_name : "${var.project_name}-${var.environment}-alarms"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-alarms"
    }
  )
}

resource "aws_sns_topic_subscription" "alarms_email" {
  count     = var.enable_sns_notifications && var.sns_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alarms[0].arn
  protocol  = "email"
  endpoint  = var.sns_email
}

resource "aws_sns_topic_subscription" "alarms_sms" {
  count     = var.enable_sns_notifications && var.sns_sms_phone_number != "" ? 1 : 0
  topic_arn = aws_sns_topic.alarms[0].arn
  protocol  = "sms"
  endpoint  = var.sns_sms_phone_number
}

resource "aws_sns_topic_subscription" "alarms_sms_multiple" {
  for_each = var.enable_sns_notifications ? toset(var.sns_sms_phone_numbers) : toset([])

  topic_arn = aws_sns_topic.alarms[0].arn
  protocol  = "sms"
  endpoint  = each.value
}


resource "aws_cloudwatch_metric_alarm" "ecs_cpu" {
  for_each = var.ecs_services

  alarm_name          = "${var.project_name}-${each.key}-ecs-cpu"
  alarm_description   = "ECS service ${each.value.service_name} CPU high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = var.alarm_period_seconds
  statistic           = "Average"
  threshold           = var.ecs_cpu_threshold_percent
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = each.value.cluster_name
    ServiceName = each.value.service_name
  }

  alarm_actions = var.enable_sns_notifications ? [aws_sns_topic.alarms[0].arn] : []

  tags = merge(var.tags, {
    MonitoredService = "ECS"
    ServiceKey       = each.key
  })
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory" {
  for_each = var.ecs_services

  alarm_name          = "${var.project_name}-${each.key}-ecs-memory"
  alarm_description   = "ECS service ${each.value.service_name} memory utilization high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = var.alarm_period_seconds
  statistic           = "Average"
  threshold           = var.ecs_memory_threshold_percent
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = each.value.cluster_name
    ServiceName = each.value.service_name
  }

  alarm_actions = var.enable_sns_notifications ? [aws_sns_topic.alarms[0].arn] : []

  tags = merge(var.tags, {
    MonitoredService = "ECS"
    ServiceKey       = each.key
  })
}


resource "aws_cloudwatch_metric_alarm" "alb_4xx" {
  for_each = var.alb_load_balancers

  alarm_name          = "${var.project_name}-${each.key}-alb-4xx"
  alarm_description   = "ALB ${each.key} target 4xx count high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "HTTPCode_Target_4XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = var.alarm_period_seconds
  statistic           = "Sum"
  threshold           = var.alb_4xx_error_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = each.value
  }

  alarm_actions = var.enable_sns_notifications ? [aws_sns_topic.alarms[0].arn] : []

  tags = merge(var.tags, {
    MonitoredService = "ALB"
    AlbKey           = each.key
  })
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  for_each = var.alb_load_balancers

  alarm_name          = "${var.project_name}-${each.key}-alb-5xx"
  alarm_description   = "ALB ${each.key} target 5xx count high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = var.alarm_period_seconds
  statistic           = "Sum"
  threshold           = var.alb_5xx_error_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = each.value
  }

  alarm_actions = var.enable_sns_notifications ? [aws_sns_topic.alarms[0].arn] : []

  tags = merge(var.tags, {
    MonitoredService = "ALB"
    AlbKey           = each.key
  })
}

resource "aws_cloudwatch_metric_alarm" "alb_latency" {
  for_each = var.alb_load_balancers

  alarm_name          = "${var.project_name}-${each.key}-alb-latency"
  alarm_description   = "ALB ${each.key} target response time high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = var.alarm_period_seconds
  statistic           = "Average"
  threshold           = var.alb_target_response_time_threshold_ms
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = each.value
  }

  alarm_actions = var.enable_sns_notifications ? [aws_sns_topic.alarms[0].arn] : []

  tags = merge(var.tags, {
    MonitoredService = "ALB"
    AlbKey           = each.key
  })
}


resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  for_each = var.rds_instance_ids

  alarm_name          = "${var.project_name}-${each.key}-rds-cpu"
  alarm_description   = "RDS ${each.value} CPU high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = var.alarm_period_seconds
  statistic           = "Average"
  threshold           = var.rds_cpu_threshold_percent
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = each.value
  }

  alarm_actions = var.enable_sns_notifications ? [aws_sns_topic.alarms[0].arn] : []

  tags = merge(var.tags, {
    MonitoredService = "RDS"
    DbKey            = each.key
  })
}

resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  for_each = var.rds_instance_ids

  alarm_name          = "${var.project_name}-${each.key}-rds-connections"
  alarm_description   = "RDS ${each.value} connection count high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = var.alarm_period_seconds
  statistic           = "Average"
  threshold           = var.rds_database_connections_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = each.value
  }

  alarm_actions = var.enable_sns_notifications ? [aws_sns_topic.alarms[0].arn] : []

  tags = merge(var.tags, {
    MonitoredService = "RDS"
    DbKey            = each.key
  })
}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage" {
  for_each = var.rds_instance_ids

  alarm_name          = "${var.project_name}-${each.key}-rds-free-storage"
  alarm_description   = "RDS ${each.value} free storage low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = var.alarm_period_seconds
  statistic           = "Average"
  threshold           = var.rds_free_storage_threshold_bytes
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = each.value
  }

  alarm_actions = var.enable_sns_notifications ? [aws_sns_topic.alarms[0].arn] : []

  tags = merge(var.tags, {
    MonitoredService = "RDS"
    DbKey            = each.key
  })
}

locals {
  has_dashboard = length(var.ecs_services) > 0 || length(var.alb_load_balancers) > 0 || length(var.rds_instance_ids) > 0

  ecs_cpu_metrics = [
    for k, v in var.ecs_services :
    ["AWS/ECS", "CPUUtilization", "ClusterName", v.cluster_name, "ServiceName", v.service_name]
  ]

  ecs_memory_metrics = [
    for k, v in var.ecs_services :
    ["AWS/ECS", "MemoryUtilization", "ClusterName", v.cluster_name, "ServiceName", v.service_name]
  ]


  alb_widgets_metrics = [
    for k, lb in var.alb_load_balancers : [
      ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", lb],
      ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", lb],
      ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", lb],
      ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", lb, { stat = "Average" }],
    ]
  ]

  ecs_row_height = length(local.ecs_cpu_metrics) > 0 ? 6 : 0

  alb_y_start = local.ecs_row_height

  rds_cpu_metrics = [
    for k, id in var.rds_instance_ids :
    ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", id]
  ]

  rds_conn_metrics = [
    for k, id in var.rds_instance_ids :
    ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", id]
  ]

  rds_storage_metrics = [
    for k, id in var.rds_instance_ids :
    ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", id]
  ]
}

resource "aws_cloudwatch_dashboard" "unified" {
  count          = local.has_dashboard ? 1 : 0
  dashboard_name = "${var.project_name}-${var.environment}-unified"

  dashboard_body = jsonencode({
    widgets = concat(
      length(local.ecs_cpu_metrics) > 0 ? [
        {
          type   = "metric"
          x      = 0
          y      = 0
          width  = 12
          height = 6
          properties = {
            metrics = local.ecs_cpu_metrics
            period  = var.alarm_period_seconds
            region  = var.aws_region
            stat    = "Average"
            title   = "ECS CPU %"
            view    = "timeSeries"
            yAxis = { left = { min = 0, max = 100 } }
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = 0
          width  = 12
          height = 6
          properties = {
            metrics = local.ecs_memory_metrics
            period  = var.alarm_period_seconds
            region  = var.aws_region
            stat    = "Average"
            title   = "ECS memory %"
            view    = "timeSeries"
            yAxis = { left = { min = 0, max = 100 } }
          }
        }
      ] : [],
      [for i, m in local.alb_widgets_metrics : {
        type   = "metric"
        x      = 0
        y      = local.alb_y_start + i * 6
        width  = 24
        height = 6
        properties = {
          metrics = m
          period  = var.alarm_period_seconds
          region  = var.aws_region
          stat    = "Sum"
          title   = "ALB — requests / 4xx / 5xx / latency"
          view    = "timeSeries"
        }
      }],
      length(local.rds_cpu_metrics) > 0 ? [
        {
          type   = "metric"
          x      = 0
          y      = local.alb_y_start + length(local.alb_widgets_metrics) * 6
          width  = 24
          height = 6
          properties = {
            metrics = concat(local.rds_cpu_metrics, local.rds_conn_metrics)
            period  = var.alarm_period_seconds
            region  = var.aws_region
            stat    = "Average"
            title   = "RDS — CPU %, DatabaseConnections"
            view    = "timeSeries"
          }
        },
        {
          type   = "metric"
          x      = 0
          y      = local.alb_y_start + length(local.alb_widgets_metrics) * 6 + 6
          width  = 24
          height = 6
          properties = {
            metrics = local.rds_storage_metrics
            period  = var.alarm_period_seconds
            region  = var.aws_region
            stat    = "Average"
            title   = "RDS — FreeStorageSpace (bytes)"
            view    = "timeSeries"
          }
        }
      ] : []
    )
  })
}

# Application log group — app can ship logs here; optional metric filters later
resource "aws_cloudwatch_log_group" "application_logs" {
  count             = var.enable_log_group_aggregation ? 1 : 0
  name              = "/aws/${var.project_name}/${var.environment}/application"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-application-logs"
  })
}
