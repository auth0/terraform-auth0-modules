resource "auth0_tenant" "this" {
  count = var.manage_tenant ? 1 : 0

  session_lifetime      = var.session_lifetime
  idle_session_lifetime = var.idle_session_lifetime
  support_email         = var.support_email
  support_url           = var.support_url

  flags {
    disable_clickjack_protection_headers   = false
    enable_public_signup_user_exists_error = true
    allow_legacy_delegation_grant_types    = false
    allow_legacy_ro_grant_types            = false
    revoke_refresh_token_grant             = var.revoke_refresh_token_grant
  }

  lifecycle {
    precondition {
      condition     = var.idle_session_lifetime <= var.session_lifetime
      error_message = "idle_session_lifetime (${var.idle_session_lifetime}h) must be less than or equal to session_lifetime (${var.session_lifetime}h)."
    }
  }
}
