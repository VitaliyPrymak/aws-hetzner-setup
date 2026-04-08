# GitHub Actions OIDC Module Variables

variable "github_org" {
  description = "GitHub organization name"
  type        = string
  default     = "changeme"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "infra"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod"
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}
