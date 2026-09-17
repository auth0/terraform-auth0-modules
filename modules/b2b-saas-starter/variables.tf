# --- App client ---------------------------------------------------------------

variable "app_name" {
  type        = string
  default     = null
  description = "Name of the app client. Required when `app_callbacks` is set."
}

variable "app_callbacks" {
  type        = list(string)
  default     = null
  description = "Post-login redirect URLs. When set, creates the app client. Must use `https://`. Exception: `http://localhost` is allowed for local development."

  validation {
    condition = var.app_callbacks == null ? true : alltrue([
      for url in var.app_callbacks :
      can(regex("^https://", url)) || can(regex("^http://localhost(:[0-9]+)?(/.*)?$", url))
    ])
    error_message = "Each callback URL must start with \"https://\". Exception: \"http://localhost\" or \"http://localhost:PORT\" is permitted for local development. Example: \"https://app.yourapp.com/callback\""
  }
}

variable "app_logout_urls" {
  type        = list(string)
  default     = null
  description = "Post-logout redirect URLs. Required when `app_callbacks` is set."
}

variable "app_type" {
  type        = string
  default     = "spa"
  description = "Application type. `spa` or `regular_web`."

  validation {
    condition     = contains(["spa", "regular_web"], var.app_type)
    error_message = "app_type must be \"spa\" or \"regular_web\"."
  }
}

variable "app_logo_uri" {
  type        = string
  default     = null
  description = "Per-app logo shown in the login widget for this specific application."
}

variable "app_origins" {
  type        = list(string)
  default     = null
  description = "Allowed web origins for CORS. Recommended for SPA apps. Example: [\"https://app.yourapp.com\"]"
}

variable "enable_refresh_token_rotation" {
  type        = bool
  default     = true
  description = "Enables rotating refresh tokens with expiring lifetime. Set to `false` for non-rotating, non-expiring tokens."
}

variable "refresh_token_lifetime" {
  type        = number
  default     = 2592000
  description = "Absolute lifetime of a refresh token in seconds. Default: 30 days. Only applies when `enable_refresh_token_rotation = true`."
}

variable "refresh_token_idle_lifetime" {
  type        = number
  default     = 1296000
  description = "Idle lifetime of a refresh token in seconds - token expires if unused for this long. Must be less than or equal to `refresh_token_lifetime`. Default: 15 days. Only applies when `enable_refresh_token_rotation = true`."
}

variable "refresh_token_leeway" {
  type        = number
  default     = 3
  description = "Grace period in seconds during which a just-rotated refresh token is still accepted. Prevents `invalid_grant` errors when a SPA fires parallel refresh requests at the same moment. Default: 3. Only applies when `enable_refresh_token_rotation = true`."

  validation {
    condition     = var.refresh_token_leeway >= 0
    error_message = "refresh_token_leeway must be zero or a positive number of seconds. Example: 3"
  }
}

variable "app_jwt_lifetime" {
  type        = number
  default     = 36000
  description = "Lifetime of JWTs issued by the app client and M2M client, in seconds. Default: 10 hours."
}

variable "app_organization_require_behavior" {
  type        = string
  default     = "pre_login_prompt"
  description = "How the app prompts for an organization at login. `pre_login_prompt` shows an organization picker before login (default), `post_login_prompt` prompts after authenticating, and `no_prompt` requires the organization to be supplied by the application (e.g. via an `organization` parameter)."

  validation {
    condition     = contains(["pre_login_prompt", "post_login_prompt", "no_prompt"], var.app_organization_require_behavior)
    error_message = "app_organization_require_behavior must be \"pre_login_prompt\", \"post_login_prompt\", or \"no_prompt\"."
  }
}

variable "app_token_endpoint_auth_method" {
  type        = string
  default     = "client_secret_post"
  description = "How a `regular_web` app authenticates to the token endpoint. `client_secret_post` sends credentials in the request body (default), `client_secret_basic` sends them in the Authorization header, and `none` is for public clients with no secret. Only applies when `app_type = \"regular_web\"`."

  validation {
    condition     = contains(["client_secret_post", "client_secret_basic", "none"], var.app_token_endpoint_auth_method)
    error_message = "app_token_endpoint_auth_method must be \"client_secret_post\", \"client_secret_basic\", or \"none\"."
  }
}

# --- Resource server ----------------------------------------------------------

variable "api_name" {
  type        = string
  default     = null
  description = "Name of the resource server. Required when `api_identifier` is set."
}

variable "api_identifier" {
  type        = string
  default     = null
  description = "API audience URL. When set, creates the resource server with RBAC enforced. Used as the JWT `aud` claim. Example: \"https://api.yourapp.com\""

  validation {
    condition     = var.api_identifier == null ? true : can(regex("^https://", var.api_identifier))
    error_message = "api_identifier must start with \"https://\". Example: \"https://api.yourapp.com\""
  }
}

variable "roles" {
  type        = list(string)
  default     = []
  description = "Role names to create. Must include any role name used as a key in `permissions`."
}

variable "permissions" {
  type        = map(list(string))
  default     = {}
  description = "Permissions assigned per role. Keys must match entries in `roles`. Example: { admin = [\"read:data\", \"write:data\"], member = [\"read:data\"] }"
}

variable "token_lifetime" {
  type        = number
  default     = 86400
  description = "Access token lifetime in seconds."
}

variable "api_allow_offline_access" {
  type        = bool
  default     = true
  description = "Whether the resource server permits offline access (refresh tokens scoped to this API). Must be `true` for the app to silently refresh API access tokens via a refresh token. Defaults to `true` so the module's rotating-refresh-token default works end-to-end."
}

variable "api_skip_consent" {
  type        = bool
  default     = true
  description = "Skips the user consent screen for verifiable first-party clients calling this API. Defaults to `true`, which is appropriate for first-party apps you own. Set to `false` to require explicit user consent (e.g. for third-party clients)."
}

# --- M2M client ---------------------------------------------------------------

variable "m2m_client_name" {
  type        = string
  default     = null
  description = "Name of the M2M client. Required when `m2m_management_api_scopes` is set."
}

variable "m2m_management_api_scopes" {
  type        = list(string)
  default     = []
  description = "Scopes granted to the M2M client for the Auth0 Management API. When non-empty, creates the M2M client and grants it access to the Management API. Common scopes: `read:users`, `update:users`, `create:organization_members`."
}

# --- Custom domain ------------------------------------------------------------

variable "custom_domain" {
  type        = string
  default     = null
  description = "Branded login domain. When set, creates the custom domain; verification is a separate opt-in step via `enable_custom_domain_verification`. Hostname only - no `https://`. Example: `login.yourapp.com`"

  validation {
    condition     = var.custom_domain == null ? true : !can(regex("^https?://", var.custom_domain))
    error_message = "custom_domain must be a hostname only - do not include \"https://\". Example: \"login.yourapp.com\""
  }
}

variable "enable_custom_domain_verification" {
  type        = bool
  default     = false
  description = "Whether to run `auth0_custom_domain_verification`. Leave `false` for the first apply: the domain is created and its DNS record is published in the `dns_verification_record` / `dns_verification_command` outputs, which Terraform prints only when the apply succeeds. Add the record to DNS, confirm it resolves, then set this to `true` and apply again to verify and activate the domain. Set it to `true` from the start only when the DNS record is created in the same Terraform run (see `examples/custom-domain-managed-dns`) - pair it with `custom_domain_dns_record_ready` so verification waits for that record. Ignored when `custom_domain` is not set."
}

variable "custom_domain_dns_record_ready" {
  type        = string
  default     = null
  description = "Ordering hook for single-apply setups where the verification DNS record is managed in the same Terraform run. Pass any attribute of that record resource (e.g. `aws_route53_record.auth0.fqdn`, `digitalocean_record.auth0.id`); the value itself is unused - it only forces the propagation wait and verification to happen after the record exists, since nothing else ties them together. Leave `null` when DNS is managed outside Terraform."
}

variable "custom_domain_propagation_wait" {
  type        = string
  default     = "10s"
  description = "How long to wait before polling Auth0 for DNS verification. Only applies when `enable_custom_domain_verification = true`. Keep a small cushion (not \"0s\") when the record is created in the same run, so the first poll does not race it. Increase if your DNS TTL is high or you are hitting rate limits (example: \"180s\"). \"0s\" is safe on the second apply, where the record is already live."
}

variable "custom_domain_verification_timeout" {
  type        = string
  default     = "15m"
  description = "How long `auth0_custom_domain_verification` polls Auth0 before giving up. Lower it (example: \"2m\") to fail fast while testing; raise it if propagation is slow."
}

# --- Branding -----------------------------------------------------------------

variable "branding_logo_url" {
  type        = string
  default     = null
  description = "Tenant-level logo shown across all apps on the Universal Login page."
}

variable "branding_primary_color" {
  type        = string
  default     = null
  description = "Primary button color. Hex format. Example: `#0059d6`"

  validation {
    condition     = var.branding_primary_color == null ? true : can(regex("^#[0-9A-Fa-f]{6}$", var.branding_primary_color))
    error_message = "branding_primary_color must be a 6-digit hex color. Example: \"#0059d6\""
  }
}

variable "branding_background_color" {
  type        = string
  default     = null
  description = "Login page background color. Hex format. Example: `#f5f5f5`"

  validation {
    condition     = var.branding_background_color == null ? true : can(regex("^#[0-9A-Fa-f]{6}$", var.branding_background_color))
    error_message = "branding_background_color must be a 6-digit hex color. Example: \"#f5f5f5\""
  }
}

# --- Tenant settings ----------------------------------------------------------

variable "session_lifetime" {
  type        = number
  default     = 168
  description = "Session validity in hours."

  validation {
    condition     = var.session_lifetime > 0
    error_message = "session_lifetime must be a positive number. Example: 168"
  }
}

variable "idle_session_lifetime" {
  type        = number
  default     = 72
  description = "Idle session timeout in hours. Must be greater than 0 and less than or equal to `session_lifetime`."

  validation {
    condition     = var.idle_session_lifetime > 0
    error_message = "idle_session_lifetime must be a positive number of hours. A value of 0 expires every session on the first idle moment, making the application unusable. Example: 72"
  }
}

variable "support_email" {
  type        = string
  default     = null
  description = "Support email shown on Auth0 error pages."
}

variable "support_url" {
  type        = string
  default     = null
  description = "Support URL shown on Auth0 error pages."
}

variable "manage_tenant" {
  type        = bool
  default     = true
  description = "Manages `auth0_tenant` - session lifetimes, security flags, support info. Set to `false` on secondary module instances. Only one instance per tenant should have this `true`."
}

variable "revoke_refresh_token_grant" {
  type        = bool
  default     = false
  description = <<-EOT
    When `true`, revoking a refresh token via the Authentication API (`POST /oauth/revoke`) also deletes the underlying grant, invalidating all sibling refresh tokens for that grant. This is a cascade-scope switch for explicit revocation - it does NOT revoke tokens on logout (Auth0 has no automatic logout-time refresh token revocation; the app must call `/oauth/revoke` itself). Default: `false`.
  EOT
}

# --- Attack protection --------------------------------------------------------

variable "enable_brute_force_protection" {
  type        = bool
  default     = true
  description = "Blocks repeated failed login attempts from the same user."
}

variable "brute_force_max_attempts" {
  type        = number
  default     = 10
  description = "Number of consecutive failed login attempts from the same user before brute-force protection blocks further attempts. Only applies when `enable_brute_force_protection = true`."
}

variable "enable_suspicious_ip_throttling" {
  type        = bool
  default     = true
  description = "Rate-limits login and signup attempts from suspicious IPs."
}

variable "suspicious_ip_pre_login_max_attempts" {
  type        = number
  default     = 100
  description = "Maximum login attempts from a single IP within the `suspicious_ip_pre_login_rate` window before throttling. Only applies when `enable_suspicious_ip_throttling = true`."
}

variable "suspicious_ip_pre_login_rate" {
  type        = number
  default     = 864000
  description = "Rate-limit window in seconds for pre-login attempts from a single IP. Only applies when `enable_suspicious_ip_throttling = true`."
}

variable "suspicious_ip_pre_registration_max_attempts" {
  type        = number
  default     = 50
  description = "Maximum signup attempts from a single IP within the `suspicious_ip_pre_registration_rate` window before throttling. Only applies when `enable_suspicious_ip_throttling = true`."
}

variable "suspicious_ip_pre_registration_rate" {
  type        = number
  default     = 1200
  description = "Rate-limit window in seconds for pre-registration attempts from a single IP. Only applies when `enable_suspicious_ip_throttling = true`."
}

variable "enable_breached_password_detection" {
  type        = bool
  default     = true
  description = "Blocks passwords found in known breach databases."
}

variable "manage_attack_protection" {
  type        = bool
  default     = true
  description = "Manages `auth0_attack_protection`. Set to `false` on secondary module instances."
}

# --- MFA ----------------------------------------------------------------------

variable "mfa_policy" {
  type        = string
  default     = "all-applications"
  description = "MFA enforcement level. `all-applications` (always require), `confidence-score` (adaptive, risk-based), or `never` (disabled)."

  validation {
    condition     = contains(["all-applications", "confidence-score", "never"], var.mfa_policy)
    error_message = "mfa_policy must be \"all-applications\", \"confidence-score\", or \"never\"."
  }
}

variable "mfa_otp" {
  type        = bool
  default     = true
  description = "Enable one-time password (authenticator app) as an MFA factor."
}

variable "mfa_email" {
  type        = bool
  default     = false
  description = "Enable email as an MFA factor."
}

variable "mfa_recovery_code" {
  type        = bool
  default     = true
  description = "Enable recovery codes so users can regain access if they lose their MFA device. Enabled by default - disabling this risks permanent user lockout."
}

variable "manage_mfa" {
  type        = bool
  default     = true
  description = "Manages `auth0_guardian`. Set to `false` on secondary module instances."
}

# --- Organizations ------------------------------------------------------------

variable "organizations" {
  type = list(object({
    name             = string
    display_name     = string
    logo_url         = optional(string, null)
    primary_color    = optional(string, null)
    background_color = optional(string, null)
    connection = optional(object({
      name                       = optional(string, null)
      type                       = string
      domain_aliases             = list(string)
      allow_signup               = optional(bool, false)
      assign_membership_on_login = optional(bool, true)
      show_as_button             = optional(bool, true)
      scopes                     = optional(list(string), null)
      sign_in_endpoint           = optional(string, null)
      signing_cert               = optional(string, null)
      client_id                  = optional(string, null)
      client_secret              = optional(string, null)
      discovery_url              = optional(string, null)
    }), null)
  }))
  default     = []
  description = <<-EOT
    Enterprise organizations to provision. Each entry creates an `auth0_organization`, and optionally an `auth0_connection` + `auth0_organization_connection`.
    - `primary_color` / `background_color`: per-org login branding.
    - `connection.allow_signup`: permit self-service signup via the org SSO (database connections only).
    - `connection.assign_membership_on_login`: default `true`; set `false` to require manual/admin-approved org membership instead of auto-enrolling every SSO user on first login.
    - `connection.show_as_button`: default `true`; whether the connection appears as an SSO button on the login page.
    - `connection.scopes`: OIDC scopes to request. Defaults to `["openid", "profile", "email"]` when omitted. Only applies to `oidc` connections.
  EOT

  validation {
    condition     = length(distinct([for o in var.organizations : o.name])) == length(var.organizations)
    error_message = "Organization names must be unique. Duplicate `name` values are silently deduplicated (last entry wins), dropping the earlier entry's connection and branding. Give each organization a distinct name."
  }

  validation {
    condition = alltrue([
      for o in var.organizations :
      o.connection == null ? true : contains(["samlp", "oidc", "auth0"], o.connection.type)
    ])
    error_message = "connection.type must be one of \"samlp\" (SAML - note the trailing \"p\"), \"oidc\", or \"auth0\" (database). The Auth0 dashboard labels SAML as \"SAML\" but the API strategy is \"samlp\"."
  }

  validation {
    condition = alltrue(flatten([
      for o in var.organizations : [
        o.primary_color == null ? true : can(regex("^#[0-9A-Fa-f]{6}$", o.primary_color)),
        o.background_color == null ? true : can(regex("^#[0-9A-Fa-f]{6}$", o.background_color)),
      ]
    ]))
    error_message = "Organization primary_color and background_color must be 6-digit hex colors. Example: \"#FF4500\""
  }
}
