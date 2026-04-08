variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Public subnets — Fargate tasks get public IPs to pull from ECR via IGW"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "ALB security group ID — ECS SG allows inbound only from this SG"
  type        = string
}

variable "services" {
  description = "Map of ECS services to create (api, customer, admin)"
  type = map(object({
    image          = string
    cpu            = number
    memory         = number
    container_port = number
    desired_count  = optional(number, 1)
    target_group_arn = string
    environment    = optional(map(string), {})
    secrets        = optional(map(string), {})
    health_check = optional(object({
      command     = list(string)
      interval    = optional(number, 30)
      timeout     = optional(number, 5)
      retries     = optional(number, 3)
      startPeriod = optional(number, 60)
    }), null)
  }))
}

variable "enable_s3_access" {
  description = "Create S3 access policy for task role (set true when s3_bucket_arn is known)"
  type        = bool
  default     = false
}

variable "s3_bucket_arn" {
  description = "S3 bucket ARN for task role (file uploads). Required when enable_s3_access=true."
  type        = string
  default     = null
}

variable "enable_ses_access" {
  description = "Grant SES SendEmail to the task role"
  type        = bool
  default     = false
}

variable "enable_container_insights" {
  type    = bool
  default = true
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "tags" {
  type    = map(string)
  default = {}
}
