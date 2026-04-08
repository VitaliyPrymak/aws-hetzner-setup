# GitHub Actions OIDC Module Outputs

output "oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider"
  value       = aws_iam_openid_connect_provider.github_actions.arn
}

output "deployment_role_arn" {
  description = "ARN of the deployment role for GitHub Actions"
  value       = aws_iam_role.github_actions.arn
}

output "deployment_role_name" {
  description = "Name of the deployment role"
  value       = aws_iam_role.github_actions.name
}

output "policy_arn" {
  description = "ARN of the deployment policy"
  value       = aws_iam_policy.terraform_deployment.arn
}
