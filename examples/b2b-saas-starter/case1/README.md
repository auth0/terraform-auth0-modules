# Case 1: App client only

The simplest useful setup - a SPA client with the module's secure defaults. Tenant
settings, attack protection, and Guardian are all managed automatically; MFA is
disabled here to keep dev iteration fast.

**Creates 4 resources:** `auth0_client` (SPA), `auth0_tenant`,
`auth0_attack_protection`, `auth0_guardian`.

Same shape as [minimal](../minimal) - start from either, then see
[Case 2](../case2) to add a protected API with RBAC.

## Usage

```shell
terraform init
terraform apply
```

Feed `app_client_id` and `issuer_url` into your app's Auth0 SDK config.

Note that `mfa_policy = "never"` still creates the `auth0_guardian` resource - it
configures the factor as disabled rather than leaving it unmanaged, so the tenant's
MFA state stays declarative instead of drifting to whatever the dashboard says.
