variable "name" {
  description = "ALB name prefix / logical name"
  type        = string
}

variable "vpc_id" {
  description = "VPC where the ALB is placed"
  type        = string
}

variable "subnet_ids" {
  description = "Public subnet IDs (≥2 AZ for ALB)"
  type        = list(string)
}

variable "certificate_arn" {
  description = "ACM certificate ARN in the same region as the ALB (not us-east-1 unless ALB is there)"
  type        = string
}

variable "hosts" {
  description = "Hostnames for host-based listener rules (must be covered by ACM SANs)"
  type = object({
    admin = string
  })
}

variable "api_path_patterns" {
  description = "Path patterns that route to the API target group (path-based routing)"
  type        = list(string)
  default     = ["/api/*"]
}

variable "target_ports" {
  description = "Container ports per service (must match ECS task definitions)"
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

variable "target_type" {
  description = "ip for ECS awsvpc/Fargate; instance for EC2 launch type bridge/host"
  type        = string
  default     = "ip"
}

variable "enable_deletion_protection" {
  type    = bool
  default = false
}

variable "access_logs" {
  description = "S3 access logs; bucket must exist and allow ELB log delivery"
  type = object({
    bucket  = string
    enabled = bool
    prefix  = optional(string, "")
  })
  default = {
    bucket  = ""
    enabled = false
    prefix  = ""
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
