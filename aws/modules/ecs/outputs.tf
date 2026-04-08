output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "cluster_arn" {
  value = aws_ecs_cluster.this.arn
}

output "service_names" {
  description = "Map of service key → ECS service name"
  value       = { for k, v in aws_ecs_service.this : k => v.name }
}

output "task_definition_arns" {
  value = { for k, v in aws_ecs_task_definition.this : k => v.arn }
}

output "security_group_id" {
  description = "ECS tasks security group — use in RDS SG ingress"
  value       = aws_security_group.ecs.id
}

output "execution_role_arn" {
  value = aws_iam_role.execution.arn
}

output "task_role_arn" {
  value = aws_iam_role.task.arn
}
