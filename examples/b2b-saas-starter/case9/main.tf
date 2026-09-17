# Case 9: Separated tenant and app configuration
#
# Tenant settings (session lifetime, branding, security) are owned by module.main_app.
# A second app (admin dashboard) delegates ownership of all three singletons
# to main_app using manage_* = false.
#
# This is the pattern to use when you have multiple apps on one tenant but want
# a clean separation between shared tenant config and per-app config.
#
# Expected resources: 14 total
#   module.main_app (6):
#     auth0_client  (SPA)
#     auth0_resource_server
#     auth0_tenant
#     auth0_attack_protection
#     auth0_guardian
#     auth0_branding
#
#   module.admin_app (8):
#     auth0_client  (regular_web)
#     auth0_client_credentials  (app)
#     auth0_resource_server
#     auth0_resource_server_scopes
#     auth0_role  (super_admin)
#     auth0_role_permission x 3

# Owns all shared tenant settings alongside the primary app.
module "main_app" {
  source = "../../../modules/b2b-saas-starter"

  app_name        = "Acme"
  app_callbacks   = ["https://app.acme.com/callback"]
  app_logout_urls = ["https://app.acme.com"]
  app_origins     = ["https://app.acme.com"]

  api_name       = "Acme API"
  api_identifier = "https://api.acme.com"

  session_lifetime      = 168
  idle_session_lifetime = 72
  support_email         = "support@acme.com"
  support_url           = "https://acme.com/support"

  branding_logo_url         = "https://acme.com/logo.png"
  branding_primary_color    = "#0059d6"
  branding_background_color = "#f5f5f5"

  mfa_policy                         = "all-applications"
  enable_brute_force_protection      = true
  enable_suspicious_ip_throttling    = true
  enable_breached_password_detection = true
}

# Admin dashboard - owns only its own app and API.
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

  # Disable singletons - already managed by main_app above.
  manage_tenant            = false
  manage_attack_protection = false
  manage_mfa               = false
}

output "main_app_client_id" {
  value = module.main_app.app_client_id
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
