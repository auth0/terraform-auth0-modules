resource "auth0_client" "m2m" {
  count = local.create_m2m ? 1 : 0

  name     = var.m2m_client_name
  app_type = "non_interactive"

  grant_types     = ["client_credentials"]
  oidc_conformant = true

  jwt_configuration {
    alg                 = "RS256"
    lifetime_in_seconds = var.app_jwt_lifetime
    secret_encoded      = false
  }

  lifecycle {
    precondition {
      condition     = var.m2m_client_name != null
      error_message = "m2m_client_name is required when m2m_management_api_scopes is set. Example: m2m_client_name = \"Acme Backend\""
    }
  }
}

resource "auth0_client_credentials" "m2m" {
  count = local.create_m2m ? 1 : 0

  client_id             = auth0_client.m2m[0].id
  authentication_method = "client_secret_post"
}

resource "auth0_client_grant" "m2m_management_api" {
  count = local.create_m2m ? 1 : 0

  client_id = auth0_client.m2m[0].id
  audience  = local.management_api_url
  scopes    = var.m2m_management_api_scopes
}
