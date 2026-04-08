output "endpoints" {
  description = "VPC interface/gateway endpoints created by this module"
  value       = aws_vpc_endpoint.aesthetics-endpoint
}

output "security_group_arn" {
  description = "ARN of the optional endpoint security group"
  value       = try(aws_security_group.aesthetic-sg[0].arn, null)
}

output "security_group_id" {
  description = "ID of the optional endpoint security group"
  value       = try(aws_security_group.aesthetic-sg[0].id, null)
}
