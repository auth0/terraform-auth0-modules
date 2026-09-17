locals {
  # Full org map - for data lookups inside resource bodies only. Never used as for_each.
  orgs_map = { for o in var.organizations : o.name => o }

  # Non-sensitive set of org names - safe to use as for_each keys.
  # nonsensitive() is required because iterating var.organizations taints any derived
  # value, even plain name strings, due to sensitive fields elsewhere in the object
  # (signing_cert, client_secret). The names themselves expose nothing sensitive.
  orgs_with_connection = nonsensitive(toset([
    for o in var.organizations : o.name
    if o.connection != null
  ]))
}

resource "auth0_organization" "this" {
  for_each = nonsensitive(toset([for o in var.organizations : o.name]))

  name         = local.orgs_map[each.key].name
  display_name = local.orgs_map[each.key].display_name

  dynamic "branding" {
    for_each = (
      local.orgs_map[each.key].logo_url != null ||
      local.orgs_map[each.key].primary_color != null ||
      local.orgs_map[each.key].background_color != null
    ) ? [1] : []
    content {
      logo_url = local.orgs_map[each.key].logo_url
      # Only include color keys that were actually provided. Sending an empty
      # string for a missing color triggers a 400 or perpetual plan drift.
      colors = (local.orgs_map[each.key].primary_color != null || local.orgs_map[each.key].background_color != null) ? merge(
        local.orgs_map[each.key].primary_color != null ? { primary = local.orgs_map[each.key].primary_color } : {},
        local.orgs_map[each.key].background_color != null ? { page_background = local.orgs_map[each.key].background_color } : {},
      ) : null
    }
  }
}

resource "auth0_connection" "this" {
  for_each = local.orgs_with_connection

  name     = coalesce(local.orgs_map[each.key].connection.name, "${each.key}-${local.orgs_map[each.key].connection.type}")
  strategy = local.orgs_map[each.key].connection.type

  options {
    domain_aliases = local.orgs_map[each.key].connection.domain_aliases

    # SAML options
    sign_in_endpoint = local.orgs_map[each.key].connection.type == "samlp" ? local.orgs_map[each.key].connection.sign_in_endpoint : null
    signing_cert     = local.orgs_map[each.key].connection.type == "samlp" ? local.orgs_map[each.key].connection.signing_cert : null

    # OIDC options
    client_id     = local.orgs_map[each.key].connection.type == "oidc" ? local.orgs_map[each.key].connection.client_id : null
    client_secret = local.orgs_map[each.key].connection.type == "oidc" ? local.orgs_map[each.key].connection.client_secret : null
    discovery_url = local.orgs_map[each.key].connection.type == "oidc" ? local.orgs_map[each.key].connection.discovery_url : null

    # OIDC scopes - defaults to standard claims when not overridden per-org.
    scopes = local.orgs_map[each.key].connection.type == "oidc" ? coalesce(local.orgs_map[each.key].connection.scopes, ["openid", "profile", "email"]) : null
  }

  lifecycle {
    precondition {
      condition = local.orgs_map[each.key].connection.type == "samlp" ? (
        local.orgs_map[each.key].connection.sign_in_endpoint != null &&
        local.orgs_map[each.key].connection.signing_cert != null
      ) : true
      error_message = "SAML connection for org \"${each.key}\" requires both sign_in_endpoint and signing_cert."
    }
    precondition {
      condition = local.orgs_map[each.key].connection.type == "oidc" ? (
        local.orgs_map[each.key].connection.client_id != null &&
        local.orgs_map[each.key].connection.client_secret != null &&
        local.orgs_map[each.key].connection.discovery_url != null
      ) : true
      error_message = "OIDC connection for org \"${each.key}\" requires client_id, client_secret, and discovery_url."
    }
  }
}

resource "auth0_organization_connection" "this" {
  for_each = local.orgs_with_connection

  organization_id            = auth0_organization.this[each.key].id
  connection_id              = auth0_connection.this[each.key].id
  assign_membership_on_login = local.orgs_map[each.key].connection.assign_membership_on_login
  show_as_button             = local.orgs_map[each.key].connection.show_as_button
  # is_signup_enabled is only valid for database connections; SAML and OIDC reject it
  is_signup_enabled = local.orgs_map[each.key].connection.type == "auth0" ? local.orgs_map[each.key].connection.allow_signup : null
}
