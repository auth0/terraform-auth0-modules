# Case 3: With M2M backend client
#
# Adds a machine-to-machine client granted access to the Auth0 Management API.
# Use this pattern when your backend needs to manage users, orgs, or roles
# programmatically (e.g. post-signup hooks, org member provisioning).
#
# Expected resources: 8
#   auth0_client x 2  (SPA + M2M)
#   auth0_client_credentials  (M2M)
#   auth0_resource_server
#   auth0_tenant
#   auth0_attack_protection
#   auth0_guardian
#   auth0_client_grant  (M2M -> Management API)

module "saas" {
  source = "../../../modules/b2b-saas-starter"

  app_name        = "Acme"
  app_callbacks   = ["https://app.acme.com/callback"]
  app_logout_urls = ["https://app.acme.com"]
  app_origins     = ["https://app.acme.com"]

  api_name       = "Acme API"
  api_identifier = "https://api.acme.com"

  m2m_client_name = "Acme Backend"
  m2m_management_api_scopes = [
    "read:users",
    "update:users",
    "create:organization_members",
    "delete:organization_members",
    "read:organizations",
  ]
}

output "app_client_id" {
  value = module.saas.app_client_id
}

output "m2m_client_id" {
  description = "M2M client ID for your backend service."
  value       = module.saas.m2m_client_id
}

output "m2m_client_secret" {
  description = "M2M client secret - store in your secrets manager."
  value       = module.saas.m2m_client_secret
  sensitive   = true
}

output "issuer_url" {
  value = module.saas.issuer_url
}

output "tenant_domain" {
  value = module.saas.tenant_domain
}
