# Full production setup - two apps on one tenant.
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

# Primary app - owns all tenant-level singletons (auth0_tenant, auth0_attack_protection, auth0_guardian).
module "main_app" {
  source = "../../../modules/b2b-saas-starter"

  # App client
  app_name        = "Acme"
  app_callbacks   = ["https://app.acme.com/callback"]
  app_logout_urls = ["https://app.acme.com"]
  app_origins     = ["https://app.acme.com"]

  # Resource server + RBAC
  api_name       = "Acme API"
  api_identifier = "https://api.acme.com"

  roles = ["admin", "member", "viewer"]
  permissions = {
    admin  = ["read:data", "write:data", "delete:data", "manage:members"]
    member = ["read:data", "write:data"]
    viewer = ["read:data"]
  }

  # M2M backend client
  m2m_client_name = "Acme Backend"
  m2m_management_api_scopes = [
    "read:users",
    "update:users",
    "create:organization_members",
    "delete:organization_members",
    "read:organizations",
  ]

  # Custom domain
  custom_domain = "login.acme.com"

  # Uncomment for Apply 2, once the record from dns_verification_record resolves.
  # enable_custom_domain_verification = true
  # custom_domain_propagation_wait    = "0s"

  # Branding
  branding_logo_url         = "https://acme.com/logo.png"
  branding_primary_color    = "#0059d6"
  branding_background_color = "#f5f5f5"

  # Tenant settings
  session_lifetime      = 168
  idle_session_lifetime = 72
  support_email         = "support@acme.com"
  support_url           = "https://acme.com/support"

  # Security
  mfa_policy                         = "all-applications"
  enable_brute_force_protection      = true
  enable_suspicious_ip_throttling    = true
  enable_breached_password_detection = true

  enable_refresh_token_rotation = true
  token_lifetime                = 3600

  # Enterprise orgs
  organizations = [
    {
      name         = "globex-corp"
      display_name = "Globex Corp"
      logo_url     = "https://globex.com/logo.png"
      connection = {
        type             = "samlp"
        domain_aliases   = ["globex.com"]
        sign_in_endpoint = "https://idp.globex.com/sso"
        signing_cert     = var.globex_signing_cert
      }
    },
    {
      name         = "initech"
      display_name = "Initech"
      connection = {
        type           = "oidc"
        domain_aliases = ["initech.com"]
        client_id      = "abc123"
        client_secret  = var.initech_oidc_secret
        discovery_url  = "https://initech.okta.com/.well-known/openid-configuration"
      }
    }
  ]
}

# Second app - admin dashboard. Delegates tenant-level singleton ownership to main_app.
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
