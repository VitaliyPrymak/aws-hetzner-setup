check "vpc_subnet_lengths" {
  assert {
    condition = (
      length(var.azs) == length(var.public_subnets) &&
      length(var.azs) == length(var.private_subnets)
    )
    error_message = "azs, public_subnets and private_subnets should be same length "
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = var.name
  cidr = var.cidr_block

  azs             = var.azs
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway = var.enable_nat_gateway
  enable_vpn_gateway = var.enable_vpn_gateway

  map_public_ip_on_launch = true

  tags = var.tags
}
