data "auth0_tenant" "current" {
  lifecycle {
    precondition {
      # auth0_role.roles and auth0_role_permission.permissions both use for_each = {}
      # when create_api is false, so preconditions on those resources never fire.
      # This data source is always instantiated, so the check reliably runs on every plan.
      condition     = (length(var.roles) == 0 && length(var.permissions) == 0) || local.create_api
      error_message = "roles and permissions require api_identifier to be set. Example: api_identifier = \"https://api.yourapp.com\""
    }
    precondition {
      condition     = var.refresh_token_leeway <= var.refresh_token_idle_lifetime
      error_message = "refresh_token_leeway (${var.refresh_token_leeway}s) must not exceed refresh_token_idle_lifetime (${var.refresh_token_idle_lifetime}s)."
    }
  }
}

locals {
  create_app_client    = var.app_callbacks != null
  create_api           = var.api_identifier != null
  create_m2m           = length(var.m2m_management_api_scopes) > 0
  create_custom_domain = var.custom_domain != null

  # Verification is opt-in and usually runs on a later apply, once the record from
  # the dns_verification_record output is live in DNS. See custom_domain.tf.
  verify_custom_domain = local.create_custom_domain && var.enable_custom_domain_verification

  create_branding = (
    var.branding_logo_url != null ||
    var.branding_primary_color != null ||
    var.branding_background_color != null
  )

  # Only hand out the custom-domain issuer once the domain is verified and active
  # ("ready"). Until then Auth0 still issues tokens with the tenant `iss`, so
  # returning the custom domain early would make backends reject every token on an
  # issuer mismatch.
  custom_domain_ready = local.create_custom_domain ? auth0_custom_domain.this[0].status == "ready" : false
  issuer_url          = local.custom_domain_ready ? "https://${var.custom_domain}/" : "https://${data.auth0_tenant.current.domain}/"
  management_api_url  = "https://${data.auth0_tenant.current.domain}/api/v2/"
}
