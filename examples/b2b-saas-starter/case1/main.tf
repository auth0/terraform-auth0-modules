# Case 1: App client only - minimal
#
# The simplest possible setup. Creates a SPA client with secure defaults:
# attack protection and MFA are managed by the module automatically.
# MFA is disabled here (mfa_policy = "never") to keep dev iteration fast.
#
# Expected resources: 4
#   auth0_client (SPA)
#   auth0_tenant
#   auth0_attack_protection
#   auth0_guardian

module "saas" {
  source = "../../../modules/b2b-saas-starter"

  app_name        = "Acme (Dev)"
  app_callbacks   = ["http://localhost:3000/callback"]
  app_logout_urls = ["http://localhost:3000"]
  app_origins     = ["http://localhost:3000"]

  mfa_policy = "never"
}

output "app_client_id" {
  description = "Client ID to use in your app's Auth0 SDK config."
  value       = module.saas.app_client_id
}

output "issuer_url" {
  description = "JWT issuer URL for backend token validation."
  value       = module.saas.issuer_url
}

output "tenant_domain" {
  description = "Raw Auth0 tenant domain for SDK configuration."
  value       = module.saas.tenant_domain
}
