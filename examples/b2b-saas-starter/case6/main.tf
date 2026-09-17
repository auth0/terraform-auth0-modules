# Case 6: Enterprise SSO - OIDC
#
# Provisions one enterprise organization with an OIDC identity provider (e.g. Okta).
# Users from initech.com are routed to their Okta tenant at login.
# Membership is assigned automatically on first login.
#
# -- Custom domain: two applies -----------------------------------------------
# This example sets custom_domain but does not manage that DNS zone, so
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
# Expected resources: 11, or 9 on apply 1 - the two verification
# resources land only when enable_custom_domain_verification = true.
#   auth0_client (SPA)
#   auth0_resource_server
#   auth0_tenant
#   auth0_attack_protection
#   auth0_guardian
#   auth0_custom_domain
#   auth0_custom_domain_verification  (apply 2)
#   time_sleep.dns_propagation        (apply 2, propagation wait)
#   auth0_organization  (initech)
#   auth0_connection    (OIDC)
#   auth0_organization_connection

module "saas" {
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

  organizations = [
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

output "app_client_id" {
  value = module.saas.app_client_id
}

output "issuer_url" {
  value = module.saas.issuer_url
}

output "tenant_domain" {
  value = module.saas.tenant_domain
}

output "dns_verification_record" {
  description = "Add this CNAME before running Apply 2 to activate the custom domain."
  value       = module.saas.dns_verification_record
}

output "dns_verification_command" {
  description = "Run this until it resolves, then re-apply with enable_custom_domain_verification = true."
  value       = module.saas.dns_verification_command
}

output "custom_domain_next_step" {
  description = "What to do next to activate the custom domain."
  value       = module.saas.custom_domain_next_step
}
