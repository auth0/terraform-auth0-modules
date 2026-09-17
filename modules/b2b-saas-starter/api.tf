resource "auth0_resource_server" "api" {
  count = local.create_api ? 1 : 0

  name       = var.api_name
  identifier = var.api_identifier

  signing_alg    = "RS256"
  token_lifetime = var.token_lifetime

  # RBAC is always enforced - this is non-negotiable for this module.
  # A resource server without RBAC would silently produce tokens without roles/permissions.
  enforce_policies = true
  token_dialect    = "access_token_authz"

  skip_consent_for_verifiable_first_party_clients = var.api_skip_consent

  # Refresh tokens scoped to this API are only issued when the resource server
  # permits offline access. Defaults to true so the module's rotating refresh
  # token default produces a working silent-refresh flow for API access.
  allow_offline_access = var.api_allow_offline_access

  lifecycle {
    precondition {
      condition     = var.api_name != null
      error_message = "api_name is required when api_identifier is set. Example: api_name = \"Acme API\""
    }
  }
}

# Only create scopes resource when permissions are defined.
# An empty-scopes resource would produce provider drift and no functional benefit.
resource "auth0_resource_server_scopes" "api" {
  count = local.create_api && length(flatten(values(var.permissions))) > 0 ? 1 : 0

  resource_server_identifier = auth0_resource_server.api[0].identifier

  dynamic "scopes" {
    for_each = toset(flatten(values(var.permissions)))
    content {
      name        = scopes.value
      description = scopes.value
    }
  }
}
