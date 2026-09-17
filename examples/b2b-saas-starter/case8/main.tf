# Case 8: Full production setup - multiple apps on one tenant
#
# Two module instances on a single tenant:
#   module.main_app  - owns all tenant-level singletons (auth0_tenant,
#                      auth0_attack_protection, auth0_guardian), the SPA,
#                      the API, M2M, branding, custom domain, and one SAML org.
#   module.admin_app - secondary instance for the admin dashboard (regular_web).
#                      Disables all three singleton resources to avoid conflicts.
#
# -- Custom domain: two applies -----------------------------------------------
# module.main_app sets custom_domain but does not manage that DNS zone, so
# activating the domain takes two applies:
#   Apply 1 -> creates auth0_custom_domain. Verification is skipped, since
#              enable_custom_domain_verification defaults to false, so the apply
#              succeeds and prints the dns_verification_record and
#              dns_verification_command outputs. Add that record at your DNS
#              provider and run the dig command until it resolves.
#   Apply 2 -> set enable_custom_domain_verification = true (and
#              custom_domain_propagation_wait = "0s", since the record is already
#              live) to verify and activate the domain.
# login.acme.com is a placeholder - point custom_domain at a host you control for
# the domain to verify. For a single apply, manage the DNS record in Terraform;
# see examples/custom-domain-managed-dns.
#
# Expected resources: 34 total, or 32 on apply 1 - the two verification
# resources land only when enable_custom_domain_verification = true.
#   module.main_app (26):
#     auth0_client x 2  (SPA + M2M)
#     auth0_client_credentials  (M2M)
#     auth0_resource_server
#     auth0_resource_server_scopes
#     auth0_role x 3  (admin, member, viewer)
#     auth0_role_permission x 7
#     auth0_tenant
#     auth0_attack_protection
#     auth0_guardian
#     auth0_custom_domain
#     auth0_custom_domain_verification  (apply 2)
#     time_sleep.dns_propagation        (apply 2, propagation wait)
#     auth0_branding
#     auth0_client_grant  (M2M -> Management API)
#     auth0_organization  (globex-corp)
#     auth0_connection    (SAML)
#     auth0_organization_connection
#
#   module.admin_app (8):
#     auth0_client  (regular_web)
#     auth0_client_credentials  (app)
#     auth0_resource_server
#     auth0_resource_server_scopes
#     auth0_role  (super_admin)
#     auth0_role_permission x 3

locals {
  globex_signing_cert = fileexists("${path.module}/cert.pem") ? file("${path.module}/cert.pem") : var.globex_signing_cert
}

# Primary app - owns all tenant-level singleton resources.
module "main_app" {
  source = "../../../modules/b2b-saas-starter"

  app_name        = "Acme"
  app_callbacks   = ["https://app.acme.com/callback"]
  app_logout_urls = ["https://app.acme.com"]
  app_origins     = ["https://app.acme.com"]
  custom_domain   = "login.acme.com"

  # Uncomment for Apply 2, once the record from dns_verification_record resolves.
  # enable_custom_domain_verification = true
  # custom_domain_propagation_wait    = "0s"

  api_name       = "Acme API"
  api_identifier = "https://api.acme.com"

  roles = ["admin", "member", "viewer"]
  permissions = {
    admin  = ["read:data", "write:data", "delete:data", "manage:members"]
    member = ["read:data", "write:data"]
    viewer = ["read:data"]
  }

  m2m_client_name = "Acme Backend"
  m2m_management_api_scopes = [
    "read:users",
    "update:users",
    "create:organization_members",
    "delete:organization_members",
    "read:organizations",
  ]

  branding_logo_url         = "https://acme.com/logo.png"
  branding_primary_color    = "#0059d6"
  branding_background_color = "#f5f5f5"

  session_lifetime      = 168
  idle_session_lifetime = 72
  support_email         = "support@acme.com"
  support_url           = "https://acme.com/support"

  mfa_policy                         = "all-applications"
  enable_brute_force_protection      = true
  enable_suspicious_ip_throttling    = true
  enable_breached_password_detection = true

  enable_refresh_token_rotation = true
  token_lifetime                = 3600

  organizations = [
    {
      name             = "globex-corp"
      display_name     = "Globex Corp"
      logo_url         = "https://globex.com/logo.png"
      primary_color    = "#FF4500"
      background_color = "#1a1a1a"
      connection = {
        type             = "samlp"
        domain_aliases   = ["globex.com"]
        sign_in_endpoint = "https://idp.globex.com/sso"
        signing_cert     = local.globex_signing_cert
      }
    }
  ]
}

# Admin dashboard - delegates all tenant-level singleton ownership to main_app.
module "admin_app" {
  source = "../../../modules/b2b-saas-starter"

  app_name        = "Acme Admin"
  app_type        = "regular_web"
  app_callbacks   = ["https://admin.acme.com/callback"]
  app_logout_urls = ["https://admin.acme.com"]
  app_origins     = ["https://admin.acme.com"]

  api_name       = "Acme Admin API"
  api_identifier = "https://admin-api.acme.com"

  roles = ["super_admin"]
  permissions = {
    super_admin = ["read:all", "write:all", "delete:all"]
  }

  # Disable singletons - already managed by main_app.
  manage_tenant            = false
  manage_attack_protection = false
  manage_mfa               = false
}

output "main_app_client_id" {
  value = module.main_app.app_client_id
}

output "main_app_m2m_client_id" {
  value = module.main_app.m2m_client_id
}

output "main_app_m2m_client_secret" {
  value     = module.main_app.m2m_client_secret
  sensitive = true
}

output "admin_app_client_id" {
  value = module.admin_app.app_client_id
}

output "admin_app_client_secret" {
  value     = module.admin_app.app_client_secret
  sensitive = true
}

output "issuer_url" {
  value = module.main_app.issuer_url
}

output "tenant_domain" {
  value = module.main_app.tenant_domain
}

output "dns_verification_record" {
  value = module.main_app.dns_verification_record
}

output "dns_verification_command" {
  description = "Run this until it resolves, then re-apply with enable_custom_domain_verification = true."
  value       = module.main_app.dns_verification_command
}

output "custom_domain_next_step" {
  description = "What to do next to activate the custom domain."
  value       = module.main_app.custom_domain_next_step
}
