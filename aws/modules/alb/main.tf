# Application Load Balancer: HTTP→HTTPS redirect, HTTPS with ACM, host-based routing to 3 target groups.
# Target attachments: ECS service registers task IPs (target_type=ip) — do not set target_id here.

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 9.0"

  name                       = var.name
  vpc_id                     = var.vpc_id
  subnets                    = var.subnet_ids
  enable_deletion_protection = var.enable_deletion_protection

  security_group_ingress_rules = {
    http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
      description = "HTTP"
    }
    https = {
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
      description = "HTTPS"
    }
  }

  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
      description = "egress-to-targets-and-VPC"
    }
  }

  access_logs = var.access_logs.enabled && var.access_logs.bucket != "" ? {
    bucket  = var.access_logs.bucket
    prefix  = var.access_logs.prefix
    enabled = true
  } : {}

  listeners = {
    http-redirect = {
      port     = 80
      protocol = "HTTP"
      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    https = {
      port            = 443
      protocol        = "HTTPS"
      ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"
      certificate_arn = var.certificate_arn

      # Default: customer site when Host does not match api/admin rules
      forward = {
        target_group_key = "customer"
      }

      rules = {
        api = {
          priority = 10
          actions = [{
            type             = "forward"
            target_group_key = "api"
          }]
          conditions = [{
            path_pattern = {
              values = var.api_path_patterns
            }
          }]
        }
        admin = {
          priority = 20
          actions = [{
            type             = "forward"
            target_group_key = "admin"
          }]
          conditions = [{
            host_header = {
              values = [var.hosts.admin]
            }
          }]
        }
      }
    }
  }

  target_groups = {
    customer = {
      name_prefix                       = "cu-"
      protocol                          = "HTTP"
      port                              = var.target_ports.customer
      target_type                       = var.target_type
      deregistration_delay              = 30
      load_balancing_cross_zone_enabled = true
      create_attachment                 = false
      health_check = {
        enabled             = true
        healthy_threshold   = 3
        unhealthy_threshold = 3
        interval            = 30
        timeout             = 5
        protocol            = "HTTP"
        path                = var.health_check_paths.customer
        matcher             = "200-399"
      }
    }
    api = {
      name_prefix                       = "ap-"
      protocol                          = "HTTP"
      port                              = var.target_ports.api
      target_type                       = var.target_type
      deregistration_delay              = 30
      load_balancing_cross_zone_enabled = true
      create_attachment                 = false
      health_check = {
        enabled             = true
        healthy_threshold   = 3
        unhealthy_threshold = 3
        interval            = 30
        timeout             = 5
        protocol            = "HTTP"
        path                = var.health_check_paths.api
        matcher             = "200-399"
      }
    }
    admin = {
      name_prefix                       = "ad-"
      protocol                          = "HTTP"
      port                              = var.target_ports.admin
      target_type                       = var.target_type
      deregistration_delay              = 30
      load_balancing_cross_zone_enabled = true
      create_attachment                 = false
      health_check = {
        enabled             = true
        healthy_threshold   = 3
        unhealthy_threshold = 3
        interval            = 30
        timeout             = 5
        protocol            = "HTTP"
        path                = var.health_check_paths.admin
        matcher             = "200-399"
      }
    }
  }

  tags = var.tags
}
