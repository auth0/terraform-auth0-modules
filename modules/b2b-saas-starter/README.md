# b2b-saas-starter

An opinionated Terraform module for standing up a B2B SaaS identity setup on
Auth0: an application client, an API (resource server) with RBAC, roles and
permissions, an optional M2M backend client, tenant security settings, MFA,
attack protection, branding, a custom login domain, and enterprise SSO
organizations (SAML / OIDC).

Resources are **presence-driven** - you get a resource when you set the input
that implies it (e.g. setting `app_callbacks` creates the app client, setting
`api_identifier` creates the resource server, a non-empty
`m2m_management_api_scopes` creates the M2M client).

```hcl
module "saas" {
  source  = "auth0/modules/auth0//modules/b2b-saas-starter"
  version = "~> 0.1"

  app_name        = "Acme"
  app_callbacks   = ["https://app.acme.com/callback"]
  app_logout_urls = ["https://app.acme.com"]
  app_origins     = ["https://app.acme.com"]

  api_name       = "Acme API"
  api_identifier = "https://api.acme.com"
}
```

See [`examples/b2b-saas-starter/`](../../examples/b2b-saas-starter/) for
scenarios from a minimal dev setup through a full multi-app production tenant
with mixed SSO.

## Design philosophy: opinionated by default, composable at the edges

This module is **opinionated** - it does not re-expose every argument of every
underlying Auth0 resource. That is a deliberate choice, and it is standard
practice for curated Terraform modules (HashiCorp's own guidance is to expose
the commonly-modified arguments and target the ~80% case, not to be a thin
wrapper over the raw resource).

There are three tiers to the interface:

1. **Curated variables** for the common case (e.g. `app_callbacks`,
   `api_identifier`, `roles`, `permissions`).
2. **Flat tuning variables** for settings you may want to override - feature
   toggles are `enable_*` booleans (`enable_refresh_token_rotation`,
   `enable_brute_force_protection`, ...) and related scalars share a common name
   prefix (`refresh_token_lifetime`, `refresh_token_idle_lifetime`,
   `refresh_token_leeway`; `suspicious_ip_pre_login_rate`, ...). Every one has a
   sensible default, so you set only what you want to change. Genuine
   collections - `organizations` - use `list(object(...))`.
3. **Fixed opinions** - a small set of values are intentionally hardcoded
   because they define what "SaaS starter" means (see below).

### Fixed opinions (not configurable)

| Setting | Value | Why |
| --- | --- | --- |
| App grant types | `authorization_code` + `refresh_token` (PKCE) | Implicit flow is deprecated per the OAuth 2.0 Security BCP. |
| `oidc_conformant` | `true` | Modern OIDC behavior. |
| Resource server RBAC | `enforce_policies = true`, `token_dialect = "access_token_authz"` | An API without RBAC silently issues tokens with no roles/permissions. |
| Signing algorithm | `RS256` | Asymmetric signing for verifiable JWTs. |
| Custom domain cert | `auth0_managed_certs` | Auth0-managed TLS. |

### Opinionated defaults you can override

These have production-ready defaults but are configurable when your product needs
something different:

| Setting | Variable | Default |
| --- | --- | --- |
| Org prompt behavior at login | `app_organization_require_behavior` | `pre_login_prompt` |
| `regular_web` token-endpoint auth | `app_token_endpoint_auth_method` | `client_secret_post` |
| Skip consent for first-party clients | `api_skip_consent` | `true` |
| OIDC connection scopes (per org) | `organizations[*].connection.scopes` | `["openid", "profile", "email"]` |
| Show SSO connection as a button (per org) | `organizations[*].connection.show_as_button` | `true` |

### Escape hatch: composing additional resources

If you need a field this module does not surface, or a resource it does not
create, **compose the raw Auth0 resource alongside the module** rather than
forking it. The module exposes the outputs you need to wire your own resources
in - for example `app_client_id`, `m2m_client_id`, `issuer_url`, and
`tenant_domain`. This is the recommended pattern (wrap/compose, don't fork).

```hcl
module "saas" {
  source          = "auth0/modules/auth0//modules/b2b-saas-starter"
  app_name        = "Acme"
  app_callbacks   = ["https://app.acme.com/callback"]
  app_logout_urls = ["https://app.acme.com"]
  api_identifier  = "https://api.acme.com"
  api_name        = "Acme API"
}

# Example: attach an extra client grant the module does not manage.
resource "auth0_client_grant" "extra" {
  client_id = module.saas.m2m_client_id
  audience  = "https://other-api.acme.com"
  scopes    = ["read:things"]
}
```

## Notes on token and session behavior

### Refresh tokens for API access

For the app to silently refresh an access token for your API, the resource
server must permit offline access. This module sets
`api_allow_offline_access = true` by default so the rotating-refresh-token flow
works end-to-end. Set it to `false` only if you explicitly do not want refresh
tokens scoped to the API audience.

### Concurrent refresh requests

The app client sets a refresh-token rotation leeway (default `3` seconds via
`refresh_token_leeway`) so that a SPA firing several parallel requests when the
access token expires does not get `invalid_grant` errors from simultaneous
rotation. Increase it if you still see races under load.

### Logout does not revoke refresh tokens

Auth0 **does not** automatically revoke a user's refresh tokens on logout.
Logout (`/v2/logout`, RP-initiated, or back-channel) clears the session layer
only; previously-issued refresh tokens remain valid until they expire, are
rotated out, or are explicitly revoked.

To invalidate refresh tokens when a user logs out (e.g. for offboarding), your
application must explicitly call `POST /oauth/revoke` (or delete the grant via
the Management API) as part of its logout flow. Setting
`revoke_refresh_token_grant = true` makes a single `/oauth/revoke`
call cascade to the entire grant (invalidating all sibling refresh tokens) - but
it is **not** a logout hook on its own; something still has to make the revoke
call.

### Custom domain and `issuer_url`

Auth0 verifies a custom domain only once its DNS record is live, so verification
is a **separate, opt-in step** (`enable_custom_domain_verification`, default
`false`) rather than part of the apply that creates the domain. That default is
what makes the manual DNS path workable: Terraform prints outputs only after a
successful apply, so verifying in the first apply would either fail or sit in a
long poll, and the record values you need would stay hidden.

**Manual DNS: two applies.**

```console
# Apply 1 - creates the domain, succeeds, prints the record.
$ terraform apply
$ terraform output dns_verification_record
{
  "method" = "cname"
  "name"   = "login.acme.com"
  "type"   = "CNAME"
  "value"  = "acme-com-cd-xxxxx.edge.tenants.auth0.com"
}

# Add that record at your DNS provider, then poll until it resolves.
$ terraform output -raw dns_verification_command
dig +short CNAME login.acme.com
$ dig +short CNAME login.acme.com
acme-com-cd-xxxxx.edge.tenants.auth0.com.

# Apply 2 - opt in to verification. The record is already live, so no wait.
$ terraform apply -var enable_custom_domain_verification=true \
                  -var custom_domain_propagation_wait=0s
```

The `custom_domain_next_step` output tells you which of these steps you are on.
`custom_domain_verification_timeout` (default `15m`) caps how long verification
polls - lower it to fail fast while testing.

**Single apply with Terraform-managed DNS.** When your DNS zone lives in the same
Terraform run (Route 53, Cloudflare, DigitalOcean, ...), skip the manual step:
create the record from `dns_verification_record`, enable verification up front,
and pass the record back in via `custom_domain_dns_record_ready` so the module's
propagation wait and verification are ordered *after* the record exists. That
ordering hook is what ties the two together - without it, nothing stops Terraform
from polling Auth0 before the record is written.

```hcl
module "saas" {
  source        = "auth0/modules/auth0//modules/b2b-saas-starter"
  custom_domain = "login.acme.com"

  enable_custom_domain_verification = true
  custom_domain_dns_record_ready    = digitalocean_record.auth0_verification.id
  custom_domain_propagation_wait    = "30s" # small cushion, not "0s"
}

resource "digitalocean_record" "auth0_verification" {
  domain = "acme.com"
  type   = module.saas.dns_verification_record.type
  name   = trimsuffix(module.saas.dns_verification_record.name, ".acme.com")
  value  = "${module.saas.dns_verification_record.value}."
}
```

See [`examples/b2b-saas-starter/custom-domain-managed-dns`](../../examples/b2b-saas-starter/custom-domain-managed-dns)
for the Route 53 version. Keep a small `custom_domain_propagation_wait` (not
`0s`) here, so the first verification poll does not race the record you just
created.

**`issuer_url`.** The output returns the tenant URL until the domain is verified
(`status == "ready"`), and only then the custom-domain URL, so a backend
configured from it always matches the `iss` claim Auth0 is currently issuing.
`status` is read at refresh time, so right after the verifying apply it may still
show the pre-verification value; re-run `terraform apply` to pick up `ready`.

---

Generated with help from the ODF tooling. For support see the
[ODF Service Desk](https://oktainc.atlassian.net/wiki/spaces/ESS/pages/701930944/Okta+Developer+Foundations+Service+Desk)
or [#odf-servicedesk](https://okta.enterprise.slack.com/archives/C097LNQ2TFA).

<!-- BEGIN_TF_DOCS -->
## Resources

| Name | Type |
|------|------|
| [auth0_attack_protection.this](https://registry.terraform.io/providers/auth0/auth0/latest/docs/resources/attack_protection) | resource |
| [auth0_branding.this](https://registry.terraform.io/providers/auth0/auth0/latest/docs/resources/branding) | resource |
| [auth0_client.app](https://registry.terraform.io/providers/auth0/auth0/latest/docs/resources/client) | resource |
| [auth0_client.m2m](https://registry.terraform.io/providers/auth0/auth0/latest/docs/resources/client) | resource |
| [auth0_client_credentials.app](https://registry.terraform.io/providers/auth0/auth0/latest/docs/resources/client_credentials) | resource |
| [auth0_client_credentials.m2m](https://registry.terraform.io/providers/auth0/auth0/latest/docs/resources/client_credentials) | resource |
| [auth0_client_grant.m2m_management_api](https://registry.terraform.io/providers/auth0/auth0/latest/docs/resources/client_grant) | resource |
| [auth0_connection.this](https://registry.terraform.io/providers/auth0/auth0/latest/docs/resources/connection) | resource |
| [auth0_custom_domain.this](https://registry.terraform.io/providers/auth0/auth0/latest/docs/resources/custom_domain) | resource |
| [auth0_custom_domain_verification.this](https://registry.terraform.io/providers/auth0/auth0/latest/docs/resources/custom_domain_verification) | resource |
| [auth0_guardian.this](https://registry.terraform.io/providers/auth0/auth0/latest/docs/resources/guardian) | resource |
| [auth0_organization.this](https://registry.terraform.io/providers/auth0/auth0/latest/docs/resources/organization) | resource |
| [auth0_organization_connection.this](https://registry.terraform.io/providers/auth0/auth0/latest/docs/resources/organization_connection) | resource |
| [auth0_resource_server.api](https://registry.terraform.io/providers/auth0/auth0/latest/docs/resources/resource_server) | resource |
| [auth0_resource_server_scopes.api](https://registry.terraform.io/providers/auth0/auth0/latest/docs/resources/resource_server_scopes) | resource |
| [auth0_role.roles](https://registry.terraform.io/providers/auth0/auth0/latest/docs/resources/role) | resource |
| [auth0_role_permission.permissions](https://registry.terraform.io/providers/auth0/auth0/latest/docs/resources/role_permission) | resource |
| [auth0_tenant.this](https://registry.terraform.io/providers/auth0/auth0/latest/docs/resources/tenant) | resource |
| [time_sleep.dns_propagation](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [auth0_tenant.current](https://registry.terraform.io/providers/auth0/auth0/latest/docs/data-sources/tenant) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_api_allow_offline_access"></a> [api\_allow\_offline\_access](#input\_api\_allow\_offline\_access) | Whether the resource server permits offline access (refresh tokens scoped to this API). Must be `true` for the app to silently refresh API access tokens via a refresh token. Defaults to `true` so the module's rotating-refresh-token default works end-to-end. | `bool` | `true` | no |
| <a name="input_api_identifier"></a> [api\_identifier](#input\_api\_identifier) | API audience URL. When set, creates the resource server with RBAC enforced. Used as the JWT `aud` claim. Example: "https://api.yourapp.com" | `string` | `null` | no |
| <a name="input_api_name"></a> [api\_name](#input\_api\_name) | Name of the resource server. Required when `api_identifier` is set. | `string` | `null` | no |
| <a name="input_api_skip_consent"></a> [api\_skip\_consent](#input\_api\_skip\_consent) | Skips the user consent screen for verifiable first-party clients calling this API. Defaults to `true`, which is appropriate for first-party apps you own. Set to `false` to require explicit user consent (e.g. for third-party clients). | `bool` | `true` | no |
| <a name="input_app_callbacks"></a> [app\_callbacks](#input\_app\_callbacks) | Post-login redirect URLs. When set, creates the app client. Must use `https://`. Exception: `http://localhost` is allowed for local development. | `list(string)` | `null` | no |
| <a name="input_app_jwt_lifetime"></a> [app\_jwt\_lifetime](#input\_app\_jwt\_lifetime) | Lifetime of JWTs issued by the app client and M2M client, in seconds. Default: 10 hours. | `number` | `36000` | no |
| <a name="input_app_logo_uri"></a> [app\_logo\_uri](#input\_app\_logo\_uri) | Per-app logo shown in the login widget for this specific application. | `string` | `null` | no |
| <a name="input_app_logout_urls"></a> [app\_logout\_urls](#input\_app\_logout\_urls) | Post-logout redirect URLs. Required when `app_callbacks` is set. | `list(string)` | `null` | no |
| <a name="input_app_name"></a> [app\_name](#input\_app\_name) | Name of the app client. Required when `app_callbacks` is set. | `string` | `null` | no |
| <a name="input_app_organization_require_behavior"></a> [app\_organization\_require\_behavior](#input\_app\_organization\_require\_behavior) | How the app prompts for an organization at login. `pre_login_prompt` shows an organization picker before login (default), `post_login_prompt` prompts after authenticating, and `no_prompt` requires the organization to be supplied by the application (e.g. via an `organization` parameter). | `string` | `"pre_login_prompt"` | no |
| <a name="input_app_origins"></a> [app\_origins](#input\_app\_origins) | Allowed web origins for CORS. Recommended for SPA apps. Example: ["https://app.yourapp.com"] | `list(string)` | `null` | no |
| <a name="input_app_token_endpoint_auth_method"></a> [app\_token\_endpoint\_auth\_method](#input\_app\_token\_endpoint\_auth\_method) | How a `regular_web` app authenticates to the token endpoint. `client_secret_post` sends credentials in the request body (default), `client_secret_basic` sends them in the Authorization header, and `none` is for public clients with no secret. Only applies when `app_type = "regular_web"`. | `string` | `"client_secret_post"` | no |
| <a name="input_app_type"></a> [app\_type](#input\_app\_type) | Application type. `spa` or `regular_web`. | `string` | `"spa"` | no |
| <a name="input_branding_background_color"></a> [branding\_background\_color](#input\_branding\_background\_color) | Login page background color. Hex format. Example: `#f5f5f5` | `string` | `null` | no |
| <a name="input_branding_logo_url"></a> [branding\_logo\_url](#input\_branding\_logo\_url) | Tenant-level logo shown across all apps on the Universal Login page. | `string` | `null` | no |
| <a name="input_branding_primary_color"></a> [branding\_primary\_color](#input\_branding\_primary\_color) | Primary button color. Hex format. Example: `#0059d6` | `string` | `null` | no |
| <a name="input_brute_force_max_attempts"></a> [brute\_force\_max\_attempts](#input\_brute\_force\_max\_attempts) | Number of consecutive failed login attempts from the same user before brute-force protection blocks further attempts. Only applies when `enable_brute_force_protection = true`. | `number` | `10` | no |
| <a name="input_custom_domain"></a> [custom\_domain](#input\_custom\_domain) | Branded login domain. When set, creates the custom domain; verification is a separate opt-in step via `enable_custom_domain_verification`. Hostname only - no `https://`. Example: `login.yourapp.com` | `string` | `null` | no |
| <a name="input_custom_domain_dns_record_ready"></a> [custom\_domain\_dns\_record\_ready](#input\_custom\_domain\_dns\_record\_ready) | Ordering hook for single-apply setups where the verification DNS record is managed in the same Terraform run. Pass any attribute of that record resource (e.g. `aws_route53_record.auth0.fqdn`, `digitalocean_record.auth0.id`); the value itself is unused - it only forces the propagation wait and verification to happen after the record exists, since nothing else ties them together. Leave `null` when DNS is managed outside Terraform. | `string` | `null` | no |
| <a name="input_custom_domain_propagation_wait"></a> [custom\_domain\_propagation\_wait](#input\_custom\_domain\_propagation\_wait) | How long to wait before polling Auth0 for DNS verification. Only applies when `enable_custom_domain_verification = true`. Keep a small cushion (not "0s") when the record is created in the same run, so the first poll does not race it. Increase if your DNS TTL is high or you are hitting rate limits (example: "180s"). "0s" is safe on the second apply, where the record is already live. | `string` | `"10s"` | no |
| <a name="input_custom_domain_verification_timeout"></a> [custom\_domain\_verification\_timeout](#input\_custom\_domain\_verification\_timeout) | How long `auth0_custom_domain_verification` polls Auth0 before giving up. Lower it (example: "2m") to fail fast while testing; raise it if propagation is slow. | `string` | `"15m"` | no |
| <a name="input_enable_breached_password_detection"></a> [enable\_breached\_password\_detection](#input\_enable\_breached\_password\_detection) | Blocks passwords found in known breach databases. | `bool` | `true` | no |
| <a name="input_enable_brute_force_protection"></a> [enable\_brute\_force\_protection](#input\_enable\_brute\_force\_protection) | Blocks repeated failed login attempts from the same user. | `bool` | `true` | no |
| <a name="input_enable_custom_domain_verification"></a> [enable\_custom\_domain\_verification](#input\_enable\_custom\_domain\_verification) | Whether to run `auth0_custom_domain_verification`. Leave `false` for the first apply: the domain is created and its DNS record is published in the `dns_verification_record` / `dns_verification_command` outputs, which Terraform prints only when the apply succeeds. Add the record to DNS, confirm it resolves, then set this to `true` and apply again to verify and activate the domain. Set it to `true` from the start only when the DNS record is created in the same Terraform run (see `examples/custom-domain-managed-dns`) - pair it with `custom_domain_dns_record_ready` so verification waits for that record. Ignored when `custom_domain` is not set. | `bool` | `false` | no |
| <a name="input_enable_refresh_token_rotation"></a> [enable\_refresh\_token\_rotation](#input\_enable\_refresh\_token\_rotation) | Enables rotating refresh tokens with expiring lifetime. Set to `false` for non-rotating, non-expiring tokens. | `bool` | `true` | no |
| <a name="input_enable_suspicious_ip_throttling"></a> [enable\_suspicious\_ip\_throttling](#input\_enable\_suspicious\_ip\_throttling) | Rate-limits login and signup attempts from suspicious IPs. | `bool` | `true` | no |
| <a name="input_idle_session_lifetime"></a> [idle\_session\_lifetime](#input\_idle\_session\_lifetime) | Idle session timeout in hours. Must be greater than 0 and less than or equal to `session_lifetime`. | `number` | `72` | no |
| <a name="input_m2m_client_name"></a> [m2m\_client\_name](#input\_m2m\_client\_name) | Name of the M2M client. Required when `m2m_management_api_scopes` is set. | `string` | `null` | no |
| <a name="input_m2m_management_api_scopes"></a> [m2m\_management\_api\_scopes](#input\_m2m\_management\_api\_scopes) | Scopes granted to the M2M client for the Auth0 Management API. When non-empty, creates the M2M client and grants it access to the Management API. Common scopes: `read:users`, `update:users`, `create:organization_members`. | `list(string)` | `[]` | no |
| <a name="input_manage_attack_protection"></a> [manage\_attack\_protection](#input\_manage\_attack\_protection) | Manages `auth0_attack_protection`. Set to `false` on secondary module instances. | `bool` | `true` | no |
| <a name="input_manage_mfa"></a> [manage\_mfa](#input\_manage\_mfa) | Manages `auth0_guardian`. Set to `false` on secondary module instances. | `bool` | `true` | no |
| <a name="input_manage_tenant"></a> [manage\_tenant](#input\_manage\_tenant) | Manages `auth0_tenant` - session lifetimes, security flags, support info. Set to `false` on secondary module instances. Only one instance per tenant should have this `true`. | `bool` | `true` | no |
| <a name="input_mfa_email"></a> [mfa\_email](#input\_mfa\_email) | Enable email as an MFA factor. | `bool` | `false` | no |
| <a name="input_mfa_otp"></a> [mfa\_otp](#input\_mfa\_otp) | Enable one-time password (authenticator app) as an MFA factor. | `bool` | `true` | no |
| <a name="input_mfa_policy"></a> [mfa\_policy](#input\_mfa\_policy) | MFA enforcement level. `all-applications` (always require), `confidence-score` (adaptive, risk-based), or `never` (disabled). | `string` | `"all-applications"` | no |
| <a name="input_mfa_recovery_code"></a> [mfa\_recovery\_code](#input\_mfa\_recovery\_code) | Enable recovery codes so users can regain access if they lose their MFA device. Enabled by default - disabling this risks permanent user lockout. | `bool` | `true` | no |
| <a name="input_organizations"></a> [organizations](#input\_organizations) | Enterprise organizations to provision. Each entry creates an `auth0_organization`, and optionally an `auth0_connection` + `auth0_organization_connection`.<br/>- `primary_color` / `background_color`: per-org login branding.<br/>- `connection.allow_signup`: permit self-service signup via the org SSO (database connections only).<br/>- `connection.assign_membership_on_login`: default `true`; set `false` to require manual/admin-approved org membership instead of auto-enrolling every SSO user on first login.<br/>- `connection.show_as_button`: default `true`; whether the connection appears as an SSO button on the login page.<br/>- `connection.scopes`: OIDC scopes to request. Defaults to `["openid", "profile", "email"]` when omitted. Only applies to `oidc` connections. | <pre>list(object({<br/>    name             = string<br/>    display_name     = string<br/>    logo_url         = optional(string, null)<br/>    primary_color    = optional(string, null)<br/>    background_color = optional(string, null)<br/>    connection = optional(object({<br/>      name                       = optional(string, null)<br/>      type                       = string<br/>      domain_aliases             = list(string)<br/>      allow_signup               = optional(bool, false)<br/>      assign_membership_on_login = optional(bool, true)<br/>      show_as_button             = optional(bool, true)<br/>      scopes                     = optional(list(string), null)<br/>      sign_in_endpoint           = optional(string, null)<br/>      signing_cert               = optional(string, null)<br/>      client_id                  = optional(string, null)<br/>      client_secret              = optional(string, null)<br/>      discovery_url              = optional(string, null)<br/>    }), null)<br/>  }))</pre> | `[]` | no |
| <a name="input_permissions"></a> [permissions](#input\_permissions) | Permissions assigned per role. Keys must match entries in `roles`. Example: { admin = ["read:data", "write:data"], member = ["read:data"] } | `map(list(string))` | `{}` | no |
| <a name="input_refresh_token_idle_lifetime"></a> [refresh\_token\_idle\_lifetime](#input\_refresh\_token\_idle\_lifetime) | Idle lifetime of a refresh token in seconds - token expires if unused for this long. Must be less than or equal to `refresh_token_lifetime`. Default: 15 days. Only applies when `enable_refresh_token_rotation = true`. | `number` | `1296000` | no |
| <a name="input_refresh_token_leeway"></a> [refresh\_token\_leeway](#input\_refresh\_token\_leeway) | Grace period in seconds during which a just-rotated refresh token is still accepted. Prevents `invalid_grant` errors when a SPA fires parallel refresh requests at the same moment. Default: 3. Only applies when `enable_refresh_token_rotation = true`. | `number` | `3` | no |
| <a name="input_refresh_token_lifetime"></a> [refresh\_token\_lifetime](#input\_refresh\_token\_lifetime) | Absolute lifetime of a refresh token in seconds. Default: 30 days. Only applies when `enable_refresh_token_rotation = true`. | `number` | `2592000` | no |
| <a name="input_revoke_refresh_token_grant"></a> [revoke\_refresh\_token\_grant](#input\_revoke\_refresh\_token\_grant) | When `true`, revoking a refresh token via the Authentication API (`POST /oauth/revoke`) also deletes the underlying grant, invalidating all sibling refresh tokens for that grant. This is a cascade-scope switch for explicit revocation - it does NOT revoke tokens on logout (Auth0 has no automatic logout-time refresh token revocation; the app must call `/oauth/revoke` itself). Default: `false`. | `bool` | `false` | no |
| <a name="input_roles"></a> [roles](#input\_roles) | Role names to create. Must include any role name used as a key in `permissions`. | `list(string)` | `[]` | no |
| <a name="input_session_lifetime"></a> [session\_lifetime](#input\_session\_lifetime) | Session validity in hours. | `number` | `168` | no |
| <a name="input_support_email"></a> [support\_email](#input\_support\_email) | Support email shown on Auth0 error pages. | `string` | `null` | no |
| <a name="input_support_url"></a> [support\_url](#input\_support\_url) | Support URL shown on Auth0 error pages. | `string` | `null` | no |
| <a name="input_suspicious_ip_pre_login_max_attempts"></a> [suspicious\_ip\_pre\_login\_max\_attempts](#input\_suspicious\_ip\_pre\_login\_max\_attempts) | Maximum login attempts from a single IP within the `suspicious_ip_pre_login_rate` window before throttling. Only applies when `enable_suspicious_ip_throttling = true`. | `number` | `100` | no |
| <a name="input_suspicious_ip_pre_login_rate"></a> [suspicious\_ip\_pre\_login\_rate](#input\_suspicious\_ip\_pre\_login\_rate) | Rate-limit window in seconds for pre-login attempts from a single IP. Only applies when `enable_suspicious_ip_throttling = true`. | `number` | `864000` | no |
| <a name="input_suspicious_ip_pre_registration_max_attempts"></a> [suspicious\_ip\_pre\_registration\_max\_attempts](#input\_suspicious\_ip\_pre\_registration\_max\_attempts) | Maximum signup attempts from a single IP within the `suspicious_ip_pre_registration_rate` window before throttling. Only applies when `enable_suspicious_ip_throttling = true`. | `number` | `50` | no |
| <a name="input_suspicious_ip_pre_registration_rate"></a> [suspicious\_ip\_pre\_registration\_rate](#input\_suspicious\_ip\_pre\_registration\_rate) | Rate-limit window in seconds for pre-registration attempts from a single IP. Only applies when `enable_suspicious_ip_throttling = true`. | `number` | `1200` | no |
| <a name="input_token_lifetime"></a> [token\_lifetime](#input\_token\_lifetime) | Access token lifetime in seconds. | `number` | `86400` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_app_client_id"></a> [app\_client\_id](#output\_app\_client\_id) | Client ID of the app. Null when `app_callbacks` is not set. |
| <a name="output_app_client_secret"></a> [app\_client\_secret](#output\_app\_client\_secret) | Client secret of the app. Only present when `app_type = "regular_web"`. Null for SPA or when `app_callbacks` is not set. |
| <a name="output_custom_domain_next_step"></a> [custom\_domain\_next\_step](#output\_custom\_domain\_next\_step) | What to do next to get the custom domain active. Null when `custom_domain` is not set. |
| <a name="output_custom_domain_status"></a> [custom\_domain\_status](#output\_custom\_domain\_status) | Verification status of the custom domain. Null when `custom_domain` is not set. |
| <a name="output_dns_verification_command"></a> [dns\_verification\_command](#output\_dns\_verification\_command) | Copy-paste shell command to check whether the verification record has propagated. Run it before enabling verification: when the output matches `dns_verification_record.value`, DNS is live and you can apply again with `enable_custom_domain_verification = true`. Null when `custom_domain` is not set. |
| <a name="output_dns_verification_record"></a> [dns\_verification\_record](#output\_dns\_verification\_record) | DNS record to create before verification. Shaped to drop straight into any DNS<br/>record resource: `type` (`CNAME` or `TXT`), `name` (the record host, an FQDN),<br/>`value` (what the record points at). `method` is the raw Auth0 method name.<br/>Null when `custom_domain` is not set. |
| <a name="output_issuer_url"></a> [issuer\_url](#output\_issuer\_url) | JWT issuer URL for backend token validation. Returns the custom domain URL only once the custom domain is verified and active (`status == "ready"`); until then it returns the Auth0 tenant URL, matching the `iss` claim Auth0 actually issues. Configure your backend from this value only after the domain is verified. |
| <a name="output_m2m_client_id"></a> [m2m\_client\_id](#output\_m2m\_client\_id) | Client ID of the M2M backend client. Null when `m2m_management_api_scopes` is empty. |
| <a name="output_m2m_client_secret"></a> [m2m\_client\_secret](#output\_m2m\_client\_secret) | Client secret of the M2M backend client. Null when `m2m_management_api_scopes` is empty. |
| <a name="output_tenant_domain"></a> [tenant\_domain](#output\_tenant\_domain) | Auth0 tenant domain (e.g. `your-tenant.auth0.com`). Use this to configure Auth0 SDKs alongside `issuer_url`. |
<!-- END_TF_DOCS -->