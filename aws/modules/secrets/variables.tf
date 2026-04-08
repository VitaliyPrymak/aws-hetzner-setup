variable "secret_name" {
  description = "Name of the secret in AWS Secrets Manager"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9/_+=.@-]{1,512}$", var.secret_name))
    error_message = "Secret name must be 1-512 characters with valid characters."
  }
}

variable "secret_string" {
  description = "Secret value (JSON string for structured secrets)"
  type        = string
  sensitive   = true
}

variable "description" {
  description = "Description of the secret"
  type        = string
  default     = ""
}

variable "recovery_window_days" {
  description = "Recovery window in days after secret deletion (7-30 days)"
  type        = number
  default     = 7

  validation {
    condition     = var.recovery_window_days >= 7 && var.recovery_window_days <= 30
    error_message = "Recovery window must be between 7 and 30 days."
  }
}

variable "enable_rotation" {
  description = "Enable automatic secret rotation"
  type        = bool
  default     = false
}

variable "rotation_days" {
  description = "Number of days between rotations (minimum 30 days)"
  type        = number
  default     = 30

  validation {
    condition     = var.rotation_days >= 30
    error_message = "Rotation interval must be at least 30 days."
  }
}

variable "rotation_lambda_arn" {
  description = "ARN of Lambda function for secret rotation (required if enable_rotation=true)"
  type        = string
  default     = null
}

variable "kms_key_id" {
  description = "KMS key ID for secret encryption (uses default if not specified)"
  type        = string
  default     = null
}

variable "tags" {
  description = "AWS tags to apply to the secret"
  type        = map(string)
  default     = {}
}
