# Case 4: With branding, custom domain, and custom roles
#
# Adds tenant-level branding (logo + colors), a custom login domain, and
# a three-tier RBAC model (admin / member / viewer).
#
# Note: custom_domain requires two terraform apply runs.
#   Apply 1 -> creates auth0_custom_domain and succeeds; verification is skipped
#              (enable_custom_domain_verification defaults to false) so the
#              dns_verification_record output is printed
#   Manual  -> add that record to your DNS provider, confirm it resolves with the
#              dns_verification_command output
#   Apply 2 -> set enable_custom_domain_verification = true to run
#              auth0_custom_domain_verification and activate the domain
#
# Expected resources: 18, or 16 on apply 1 - the two verification
# resources land only when enable_custom_domain_verification = true.
#   auth0_client (SPA)
#   auth0_resource_server
#   auth0_resource_server_scopes
#   auth0_role x 3  (admin, member, viewer)
#   auth0_role_permission x 5
#   auth0_tenant
#   auth0_attack_protection
#   auth0_guardian
#   auth0_custom_domain
#   auth0_custom_domain_verification  (apply 2)
#   time_sleep.dns_propagation        (apply 2, propagation wait)
#   auth0_branding

module "saas" {
  source = "../../../modules/b2b-saas-starter"

  app_name        = "Acme"
  app_callbacks   = ["https://app.acme.com/callback"]
  app_logout_urls = ["https://app.acme.com"]
  app_origins     = ["https://app.acme.com"]
  custom_domain   = "login.acme.com"

  # Uncomment for Apply 2, once the CNAME from dns_verification_record resolves.
  # enable_custom_domain_verification = true

  # The record is already live by Apply 2, so no wait is needed. If your DNS
  # provider has a high TTL and you are verifying sooner, raise this instead -
  # verification polling times out after custom_domain_verification_timeout
  # (default 15m), so the wait must cover propagation.
  # custom_domain_propagation_wait = "0s"

  api_name       = "Acme API"
  api_identifier = "https://api.acme.com"

  roles = ["admin", "member", "viewer"]
  permissions = {
    admin  = ["read:reports", "write:reports", "manage:members"]
    member = ["read:reports"]
    viewer = ["read:reports"]
  }

  branding_logo_url         = "https://acme.com/logo.png"
  branding_primary_color    = "#0059d6"
  branding_background_color = "#f5f5f5"
}

output "app_client_id" {
  value = module.saas.app_client_id
}

output "issuer_url" {
  description = "Returns the tenant URL until the custom domain is verified (status 'ready'), then https://login.acme.com/. Configure your backend from this only after verification."
  value       = module.saas.issuer_url
}

output "tenant_domain" {
  value = module.saas.tenant_domain
}

output "custom_domain_status" {
  description = "Check this after Apply 1 - must be 'ready' before the domain is usable."
  value       = module.saas.custom_domain_status
}

output "dns_verification_record" {
  description = "Add this record to your DNS provider before running Apply 2."
  value       = module.saas.dns_verification_record
}

output "dns_verification_command" {
  description = "Run this until it resolves, then run Apply 2."
  value       = module.saas.dns_verification_command
}

output "custom_domain_next_step" {
  description = "What to do next to activate the custom domain."
  value       = module.saas.custom_domain_next_step
}
