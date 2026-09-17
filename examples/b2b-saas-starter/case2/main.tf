# Case 2: With resource server and RBAC
#
# Adds a protected API with two roles (admin, member) and scoped permissions.
# RBAC is always enforced - roles and permissions appear in every access token.
#
# Expected resources: 11
#   auth0_client (SPA)
#   auth0_resource_server
#   auth0_resource_server_scopes
#   auth0_role x 2  (admin, member)
#   auth0_role_permission x 3  (admin -> read:data + write:data, member -> read:data)
#   auth0_tenant
#   auth0_attack_protection
#   auth0_guardian

module "saas" {
  source = "../../../modules/b2b-saas-starter"

  app_name        = "Acme"
  app_callbacks   = ["https://app.acme.com/callback"]
  app_logout_urls = ["https://app.acme.com"]
  app_origins     = ["https://app.acme.com"]

  api_name       = "Acme API"
  api_identifier = "https://api.acme.com"

  roles = ["admin", "member"]
  permissions = {
    admin  = ["read:data", "write:data"]
    member = ["read:data"]
  }
}

output "app_client_id" {
  value = module.saas.app_client_id
}

output "issuer_url" {
  value = module.saas.issuer_url
}

output "tenant_domain" {
  value = module.saas.tenant_domain
}
