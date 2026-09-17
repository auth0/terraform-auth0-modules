output "app_client_id" {
  description = "Client ID of the app. Null when `app_callbacks` is not set."
  value       = local.create_app_client ? auth0_client.app[0].client_id : null
}

output "app_client_secret" {
  description = "Client secret of the app. Only present when `app_type = \"regular_web\"`. Null for SPA or when `app_callbacks` is not set."
  sensitive   = true
  value = (
    local.create_app_client && var.app_type == "regular_web"
    ? auth0_client_credentials.app[0].client_secret
    : null
  )
}

output "m2m_client_id" {
  description = "Client ID of the M2M backend client. Null when `m2m_management_api_scopes` is empty."
  value       = local.create_m2m ? auth0_client.m2m[0].client_id : null
}

output "m2m_client_secret" {
  description = "Client secret of the M2M backend client. Null when `m2m_management_api_scopes` is empty."
  sensitive   = true
  value       = local.create_m2m ? auth0_client_credentials.m2m[0].client_secret : null
}

output "issuer_url" {
  description = "JWT issuer URL for backend token validation. Returns the custom domain URL only once the custom domain is verified and active (`status == \"ready\"`); until then it returns the Auth0 tenant URL, matching the `iss` claim Auth0 actually issues. Configure your backend from this value only after the domain is verified."
  value       = local.issuer_url
}

output "custom_domain_status" {
  description = "Verification status of the custom domain. Null when `custom_domain` is not set."
  value       = local.create_custom_domain ? auth0_custom_domain.this[0].status : null
}

output "tenant_domain" {
  description = "Auth0 tenant domain (e.g. `your-tenant.auth0.com`). Use this to configure Auth0 SDKs alongside `issuer_url`."
  value       = data.auth0_tenant.current.domain
}

output "dns_verification_record" {
  description = <<-EOT
    DNS record to create before verification. Shaped to drop straight into any DNS
    record resource: `type` (`CNAME` or `TXT`), `name` (the record host, an FQDN),
    `value` (what the record points at). `method` is the raw Auth0 method name.
    Null when `custom_domain` is not set.
  EOT
  value = local.create_custom_domain ? {
    # Auth0 returns exactly one verification method per custom domain; [0] is always correct.
    type   = upper(auth0_custom_domain.this[0].verification[0].methods[0].name)
    name   = auth0_custom_domain.this[0].verification[0].methods[0].domain
    value  = auth0_custom_domain.this[0].verification[0].methods[0].record
    method = auth0_custom_domain.this[0].verification[0].methods[0].name
  } : null
}

output "dns_verification_command" {
  description = "Copy-paste shell command to check whether the verification record has propagated. Run it before enabling verification: when the output matches `dns_verification_record.value`, DNS is live and you can apply again with `enable_custom_domain_verification = true`. Null when `custom_domain` is not set."
  value = local.create_custom_domain ? format(
    "dig +short %s %s",
    upper(auth0_custom_domain.this[0].verification[0].methods[0].name),
    auth0_custom_domain.this[0].verification[0].methods[0].domain,
  ) : null
}

output "custom_domain_next_step" {
  description = "What to do next to get the custom domain active. Null when `custom_domain` is not set."
  value = (
    !local.create_custom_domain
    ? null
    : local.custom_domain_ready
    ? "Custom domain ${var.custom_domain} is active. issuer_url now returns https://${var.custom_domain}/."
    : !var.enable_custom_domain_verification
    ? "Create the DNS record from the dns_verification_record output (${upper(auth0_custom_domain.this[0].verification[0].methods[0].name)} ${auth0_custom_domain.this[0].verification[0].methods[0].domain} -> ${auth0_custom_domain.this[0].verification[0].methods[0].record}), confirm it resolves with the dns_verification_command output, then set enable_custom_domain_verification = true and apply again."
    : "Verification has run; the last-refreshed status is \"${auth0_custom_domain.this[0].status}\". This value is read before verification, so re-run terraform apply (or terraform refresh) to pick up the final status. If it stays \"pending\", confirm the DNS record still resolves using the dns_verification_command output."
  )
}
