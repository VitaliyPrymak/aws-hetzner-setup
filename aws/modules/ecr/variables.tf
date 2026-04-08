variable "repository_name" {
  description = "ECR repository name"
  type        = string
  validation {
    condition     = length(var.repository_name) > 0 && length(var.repository_name) <= 256
    error_message = "Repository name must be between 1 and 256 characters."
  }
}

variable "image_tag_mutability" {
  description = "ECR image tag mutability (MUTABLE or IMMUTABLE)"
  type        = string
  default     = "MUTABLE"
  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "Image tag mutability must be MUTABLE or IMMUTABLE."
  }
}

variable "scan_on_push" {
  description = "Enable ECR image scanning on push"
  type        = bool
  default     = true
}

variable "lifecycle_policy_count" {
  description = "Number of images to retain (0 to disable lifecycle policy)"
  type        = number
  default     = 10
  validation {
    condition     = var.lifecycle_policy_count >= 0 && var.lifecycle_policy_count <= 1000
    error_message = "Lifecycle policy count must be between 0 and 1000."
  }
}

variable "encryption_type" {
  description = "ECR encryption type (AES256 or KMS)"
  type        = string
  default     = "AES256"
  validation {
    condition     = contains(["AES256", "KMS"], var.encryption_type)
    error_message = "Encryption type must be AES256 or KMS."
  }
}

variable "kms_key_arn" {
  description = "KMS key ARN for ECR encryption (required if encryption_type=KMS)"
  type        = string
  default     = null
}

variable "allowed_account_ids" {
  description = "AWS account IDs allowed to pull images (for cross-account access)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to ECR repository"
  type        = map(string)
  default     = {}
}

variable "force_delete" {
  description = "If true, deletes all images in repository when destroying (use with caution)"
  type        = bool
  default     = false
}
