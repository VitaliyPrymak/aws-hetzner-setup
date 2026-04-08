terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "= 4.44.0"
    }
  }
}

provider "cloudflare" {}

locals {
  app_ip = "example-ip"
}

data "cloudflare_zone" "domain" {
  name = var.zone_name
}

resource "cloudflare_zone_settings_override" "settings" {
  zone_id = data.cloudflare_zone.domain.id

  settings {
    ssl                       = "full"
    min_tls_version           = "1.2"
    tls_1_3                   = "on"
    security_level            = "medium"
    always_use_https          = "on"
    automatic_https_rewrites  = "on"
    opportunistic_encryption  = "on"
    brotli                    = "on"
    http3                     = "on"
    browser_cache_ttl         = 0
    rocket_loader             = "off"
    development_mode          = "off"
  }
}

resource "cloudflare_record" "root_a" {
  zone_id = data.cloudflare_zone.domain.id
  name    = var.zone_name
  content = local.app_ip
  type    = "A"
  proxied = true
  ttl     = 1
}

resource "cloudflare_record" "admin_a" {
  zone_id = data.cloudflare_zone.domain.id
  name    = "admin"
  content = local.app_ip
  type    = "A"
  proxied = true
  ttl     = 1
}

resource "cloudflare_ruleset" "custom_firewall" {
  zone_id = data.cloudflare_zone.domain.id
  name    = "Custom security rules"
  kind    = "zone"
  phase   = "http_request_firewall_custom"

  rules {
    action      = "block"
    description = "Block known scanner user-agents"
    enabled     = true
    expression  = "(http.user_agent contains \"zgrab\") or (http.user_agent contains \"masscan\") or (http.user_agent contains \"sqlmap\") or (http.user_agent contains \"nikto\")"
  }

  rules {
    action      = "managed_challenge"
    description = "Challenge non-UA on admin host"
    enabled     = true
    expression  = "(http.host eq \"admin.${var.zone_name}\") and not (ip.geoip.country in {\"UA\" \"PL\" \"DE\"})"
  }
}

resource "cloudflare_ruleset" "rate_limits" {
  zone_id = data.cloudflare_zone.domain.id
  name    = "Rate limits"
  kind    = "zone"
  phase   = "http_ratelimit"

  rules {
    action      = "block"
    description = "Login brute-force protection"
    enabled     = true
    expression  = <<-EOT
      (http.request.method eq "POST") and (
        http.request.uri.path eq "/login" or
        http.request.uri.path eq "/signin" or
        http.request.uri.path eq "/api/auth/login" or
        http.request.uri.path eq "/api/v1/auth/login" or
        http.request.uri.path eq "/api/v1/auth/token"
      )
    EOT
    ratelimit {
      characteristics     = ["ip.src", "cf.colo.id"]
      period              = 10
      requests_per_period = 10
      mitigation_timeout  = 10
    }
  }
}
