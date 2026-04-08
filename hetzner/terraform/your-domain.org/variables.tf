variable "zone_name" {
  description = "Domain zone name"
  type        = string
  default     = "staging.example.com"
}

variable "cloudflare_account_id" {
  description = "Cloudflare account id (Dashboard → account details)"
  type        = string
  default     = "changeme-cloudflare-account-id"
}
