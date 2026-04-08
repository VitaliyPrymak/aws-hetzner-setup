variable "name" {
  type        = string
  description = "Budget name in AWS Cost Management"
}

variable "monthly_limit_usd" {
  type        = number
  description = "Monthly cost limit in USD"
}

variable "time_period_start" {
  type        = string
  description = "Budget start (UTC), format YYYY-MM-DD_HH:MM"
  default     = "2026-01-01_00:00"
}

variable "notification_emails" {
  type        = list(string)
  description = "Emails for budget alerts (must confirm AWS subscription email on first use)"
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
