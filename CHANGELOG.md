# Changelog

All notable changes to the modules in this repository will be documented in this
file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This repository uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Every module shares a single release tag, so entries are grouped by module.

---

## [Unreleased]

---

## [0.1.0] - 2026-09-21

Initial release.

### b2b-saas-starter

Initial release of the Auth0 B2B SaaS Starter Terraform module.

Configuration is exposed as flat, intent-named variables, matching the convention
used by mature modules such as `terraform-aws-modules` and Azure Verified
Modules: feature toggles are `enable_*` booleans, related scalars share a common
name prefix, and only genuine collections (`organizations`) use objects.

### Resources

- **App client** (`auth0_client`) - SPA and `regular_web` types with PKCE,
  rotating refresh tokens, and the org login flow enabled by default.
  Presence-driven on `app_callbacks`.
- **Resource server** (`auth0_resource_server`) - RBAC always on
  (`enforce_policies = true`, `token_dialect = "access_token_authz"`), since an
  API without RBAC silently issues tokens carrying no roles or permissions.
  Presence-driven on `api_identifier`. `api_allow_offline_access` (default
  `true`) lets refresh tokens scoped to the API audience be issued, so the
  rotating-refresh-token flow works end to end.
- **Roles and permissions** (`auth0_role`, `auth0_role_permission`) - flat
  expansion from a `map(list(string))`, with cross-variable validation that every
  permission belongs to a declared role.
- **M2M client** (`auth0_client`, `auth0_client_grant`) - non-interactive client
  with a Management API grant. Presence-driven on
  `m2m_management_api_scopes`.
- **Tenant settings** (`auth0_tenant`) - session lifetimes, support email and
  URL, legacy grant types disabled.
- **Attack protection** (`auth0_attack_protection`) - brute force, suspicious IP
  throttling, and breached password detection, all enabled by default with
  configurable thresholds: `brute_force_max_attempts`,
  `suspicious_ip_pre_login_max_attempts`, `suspicious_ip_pre_login_rate`,
  `suspicious_ip_pre_registration_max_attempts`,
  `suspicious_ip_pre_registration_rate`.
- **MFA** (`auth0_guardian`) - TOTP enabled by default; email and recovery codes
  available as opt-in variables.
- **Branding** (`auth0_branding`) - logo, primary color, background color.
  Presence-driven; a color is only sent when set, so a partial branding config
  does not push an empty string and cause apply failure or plan drift.
- **Custom domain** (`auth0_custom_domain`, `auth0_custom_domain_verification`) -
  see the two-phase flow below.
- **Organizations** (`auth0_organization`, `auth0_connection`,
  `auth0_organization_connection`) - SAML and OIDC enterprise SSO, per-org
  branding colors, and a `nonsensitive()` `for_each` pattern so sensitive IdP
  credentials can key the map.

### Custom domain: two-phase by design

Auth0 can only verify a domain whose DNS record is already live, and with
manually-managed DNS that record cannot be created until the record values have
been read out of Terraform. Verification is therefore a separate, opt-in step:

- **`enable_custom_domain_verification`** (bool, default `false`) - gates
  `auth0_custom_domain_verification` and the propagation wait. With the default,
  the first apply creates the domain, succeeds, and prints the
  `dns_verification_record` / `dns_verification_command` outputs. Set it to
  `true` for the apply that verifies.
- **`custom_domain_dns_record_ready`** (string, default `null`) - ordering hook
  for single-apply setups. Pass any attribute of the DNS record resource managed
  in the same run and the propagation wait, and therefore verification, is
  sequenced after that record exists.
- **`custom_domain_propagation_wait`** (string, default `10s`) - cushion before
  Auth0 is polled, so the first poll does not race a freshly written record.
- **`custom_domain_verification_timeout`** (string, default `15m`) - how long
  verification polls before giving up. Lower it to fail fast while testing.
- **`custom_domain_next_step`** output - states what to do next to activate the
  domain: create the record, enable verification, refresh, or done.
- **`dns_verification_record`** output - shaped to drop straight into a DNS
  record resource: `type` (`CNAME` or `TXT`, upper-cased), `name` (the record
  host FQDN as Auth0 asks for it), `value` (the record target), and `method` for
  the raw Auth0 method name.
- **`issuer_url`** output - returns the tenant URL until the domain is verified
  (`status == "ready"`), so a backend configured from it always matches the `iss`
  claim Auth0 is currently issuing.

### Tokens and sessions

- **`enable_refresh_token_rotation`** (bool, default `true`) with
  `refresh_token_lifetime`, `refresh_token_idle_lifetime`, and
  **`refresh_token_leeway`** (number, default `3`) - the leeway is a grace period
  in seconds during which a just-rotated refresh token is still accepted, so
  concurrent SPA refreshes do not fail with `invalid_grant`. The
  `refresh_token_idle_lifetime <= refresh_token_lifetime` relationship is
  enforced as a resource precondition, since cross-variable validation requires
  Terraform >= 1.9 and this module supports >= 1.3.0.
- **`revoke_refresh_token_grant`** (bool, default `false`) - cascade-scope switch
  for explicit refresh-token revocation via the Authentication API.

### Configurable opinions

Defaults are production-ready; override when the product needs something else:
`app_organization_require_behavior` (`pre_login_prompt`),
`app_token_endpoint_auth_method` (`client_secret_post`), `api_skip_consent`
(`true`), per-org `connection.scopes` (`["openid", "profile", "email"]` for
OIDC), per-org `connection.show_as_button` (`true`), and
`organizations[*].connection.assign_membership_on_login` (`true`; set `false` to
require admin-approved org membership).

### Validation

`connection.type` accepts `samlp` / `oidc` / `auth0`; duplicate organization
names are rejected; hex format is checked on tenant and per-org colors;
`custom_domain` must be a bare hostname; `idle_session_lifetime` and
`session_lifetime` must be positive.

### Multi-instance support

- **Singleton management flags** - `manage_tenant`, `manage_attack_protection`,
  `manage_mfa` (default `true`). Set them to `false` on secondary module
  instances so the one-per-tenant resources are owned by exactly one instance.

### Repo

- **Examples** - nine case directories plus `minimal`, `full`, and
  `custom-domain-managed-dns`, covering a minimal dev setup through a full
  multi-app production tenant with mixed SSO.
- **GitHub Actions CI** - `terraform fmt`, `terraform validate` across every
  module and example, and recursive `tflint` on every push and pull request.
- **Apache 2.0 license.**
