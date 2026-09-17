locals {
  # Modern SPAs use PKCE-based authorization_code only - implicit is deprecated per OAuth 2.0 Security BCP.
  app_grant_types = ["authorization_code", "refresh_token"]
}

resource "auth0_client" "app" {
  count = local.create_app_client ? 1 : 0

  name     = var.app_name
  app_type = var.app_type
  logo_uri = var.app_logo_uri

  callbacks           = var.app_callbacks
  allowed_logout_urls = var.app_logout_urls
  allowed_origins     = var.app_origins
  web_origins         = var.app_origins

  grant_types     = local.app_grant_types
  oidc_conformant = true

  organization_usage            = "allow"
  organization_require_behavior = var.app_organization_require_behavior

  refresh_token {
    rotation_type                = var.enable_refresh_token_rotation ? "rotating" : "non-rotating"
    expiration_type              = var.enable_refresh_token_rotation ? "expiring" : "non-expiring"
    token_lifetime               = var.refresh_token_lifetime
    idle_token_lifetime          = var.refresh_token_idle_lifetime
    infinite_token_lifetime      = !var.enable_refresh_token_rotation
    infinite_idle_token_lifetime = !var.enable_refresh_token_rotation
    leeway                       = var.refresh_token_leeway
  }

  jwt_configuration {
    alg                 = "RS256"
    lifetime_in_seconds = var.app_jwt_lifetime
    secret_encoded      = false
  }

  lifecycle {
    precondition {
      condition     = var.app_name != null
      error_message = "app_name is required when app_callbacks is set. Example: app_name = \"Acme\""
    }
    precondition {
      condition     = var.app_logout_urls != null
      error_message = "app_logout_urls is required when app_callbacks is set. Example: app_logout_urls = [\"https://app.yourapp.com\"]"
    }
    # Cross-variable checks live here, not in variable validation blocks:
    # variable-to-variable references require Terraform >= 1.9, but this module
    # supports >= 1.3.0.
    precondition {
      condition     = var.refresh_token_idle_lifetime <= var.refresh_token_lifetime
      error_message = "refresh_token_idle_lifetime (${var.refresh_token_idle_lifetime}s) must be less than or equal to refresh_token_lifetime (${var.refresh_token_lifetime}s) - otherwise the idle timer can never trigger before the absolute lifetime expires."
    }
  }
}

# Client credentials are only meaningful for regular_web apps - SPAs use PKCE without a secret.
resource "auth0_client_credentials" "app" {
  count = local.create_app_client && var.app_type == "regular_web" ? 1 : 0

  client_id             = auth0_client.app[0].id
  authentication_method = var.app_token_endpoint_auth_method
}
