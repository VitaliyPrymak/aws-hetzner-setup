resource "aws_budgets_budget" "monthly" {
  count = length(var.notification_emails) > 0 ? 1 : 0

  name         = var.name
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  time_period_start = var.time_period_start

  # ~80% of monthly cap (early warning)
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = floor(var.monthly_limit_usd * 0.8)
    threshold_type             = "ABSOLUTE_VALUE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.notification_emails
  }

  # Hard cap exceeded
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = var.monthly_limit_usd
    threshold_type             = "ABSOLUTE_VALUE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.notification_emails
  }

  # Forecast predicts going over the cap this month
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = var.monthly_limit_usd
    threshold_type             = "ABSOLUTE_VALUE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.notification_emails
  }

  tags = var.tags
}
