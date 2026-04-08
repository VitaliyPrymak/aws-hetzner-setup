output "vpc_id" {
  value = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  value = module.vpc.vpc_cidr_block
}

output "public_subnets" {
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  value       = module.vpc.private_subnets
}

output "public_route_table_ids" {
  value = module.vpc.public_route_table_ids
}

output "private_route_table_ids" {
  value       = module.vpc.private_route_table_ids
}

output "igw_id" {
  value       = module.vpc.igw_id
}

output "default_security_group_id" {
  value = module.vpc.default_security_group_id
}
