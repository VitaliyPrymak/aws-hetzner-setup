output "budget_name" {
  value = try(aws_budgets_budget.monthly[0].name, null)
}
