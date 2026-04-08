variable "project_name" {
  description = "Project name for CloudWatch resource naming"
  type        = string

  validation {
    condition     = length(var.project_name) > 0 && length(var.project_name) <= 64
    error_message = "Project name must be between 1 and 64 characters."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "aws_region" {
  description = "AWS region for CloudWatch resources"
  type        = string
  default     = "eu-central-1"
}


variable "ecs_services" {
  description = "ECS services to monitor (logical key -> cluster + service name). Dimensions: ClusterName, ServiceName."
  type = map(object({
    cluster_name = string
    service_name = string
  }))
  default = {}
}

variable "ecs_cpu_threshold_percent" {
  description = "Average CPU % over the period to trigger alarm"
  type        = number
  default     = 85
}

variable "ecs_memory_threshold_percent" {
  description = "Average memory utilization % to trigger alarm"
  type        = number
  default     = 85
}


variable "alb_load_balancers" {
  description = "ALB LoadBalancer dimension values (e.g. app/my-alb/abc123). From aws_lb or console."
  type        = map(string)
  default     = {}
}

variable "alb_4xx_error_threshold" {
  description = "Sum of HTTPCode_Target_4XX_Count to trigger alarm (can be noisy; raise in prod)"
  type        = number
  default     = 100
}

variable "alb_5xx_error_threshold" {
  description = "Sum of HTTPCode_Target_5XX_Count to trigger alarm"
  type        = number
  default     = 10
}

variable "alb_target_response_time_threshold_ms" {
  description = "Average TargetResponseTime in ms (ALB -> targets)"
  type        = number
  default     = 2000
}


variable "rds_instance_ids" {
  description = "RDS DBInstanceIdentifier values to monitor"
  type        = map(string)
  default     = {}
}

variable "rds_cpu_threshold_percent" {
  description = "Average CPU % for RDS instance"
  type        = number
  default     = 80
}

variable "rds_database_connections_threshold" {
  description = "Max connections (Average) to trigger alarm"
  type        = number
  default     = 100
}

variable "rds_free_storage_threshold_bytes" {
  description = "Alarm when FreeStorageSpace falls below this (bytes)"
  type        = number
  default     = 2147483648 # 2 GiB
}


variable "enable_sns_notifications" {
  description = "Enable SNS notifications for CloudWatch alarms"
  type        = bool
  default     = true
}

variable "sns_email" {
  description = "Email address for SNS alarm notifications"
  type        = string
  default     = ""

  validation {
    condition     = var.sns_email == "" || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.sns_email))
    error_message = "SNS email must be a valid email address or empty string."
  }
}

variable "sns_topic_name" {
  description = "Name of SNS topic for alarms (auto-generated if empty)"
  type        = string
  default     = ""
}

variable "sns_sms_phone_number" {
  description = "Phone number for SNS SMS (E.164)"
  type        = string
  default     = ""
  validation {
    condition     = var.sns_sms_phone_number == "" || can(regex("^\\+[1-9]\\d{1,14}$", var.sns_sms_phone_number))
    error_message = "SNS SMS phone number must be in E.164 format or empty."
  }
}

variable "sns_sms_phone_numbers" {
  description = "Multiple SMS recipients (E.164)"
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for num in var.sns_sms_phone_numbers : can(regex("^\\+[1-9]\\d{1,14}$", num))
    ])
    error_message = "All SMS phone numbers must be in E.164 format."
  }
}


variable "enable_log_group_aggregation" {
  description = "Create application CloudWatch log group for app logs / future metric filters"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period in days"
  type        = number
  default     = 14

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch value."
  }
}

variable "log_group_patterns" {
  description = "Documentation / future use — ECS often uses /ecs/<family>"
  type        = list(string)
  default     = ["/ecs/*", "/aws/applicationelb/*"]
}

variable "custom_metric_namespace" {
  description = "Namespace for PutMetricData from the app (e.g. Aesthetic/App)"
  type        = string
  default     = "Aesthetic/App"

  validation {
    condition     = length(var.custom_metric_namespace) > 0 && length(var.custom_metric_namespace) <= 256
    error_message = "Custom metric namespace must be between 1 and 256 characters."
  }
}

variable "enable_custom_metrics" {
  description = "Reserved — enable app custom metrics documentation"
  type        = bool
  default     = false
}


variable "alarm_evaluation_periods" {
  description = "Number of periods to evaluate for alarms"
  type        = number
  default     = 2

  validation {
    condition     = var.alarm_evaluation_periods > 0 && var.alarm_evaluation_periods <= 4
    error_message = "Evaluation periods must be between 1 and 4."
  }
}

variable "alarm_period_seconds" {
  description = "Period in seconds for alarm evaluation"
  type        = number
  default     = 300

  validation {
    condition     = contains([60, 300, 600, 900, 1800, 3600], var.alarm_period_seconds)
    error_message = "Alarm period must be 60, 300, 600, 900, 1800, or 3600 seconds."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
