# Minimal

The smallest useful configuration: one SPA client pointed at `localhost`, with
MFA turned off so dev iteration stays fast. Everything else takes the module's
defaults, which still includes tenant settings, attack protection, and Guardian.

Start here, then see [Case 2](../case2) to add a protected API with RBAC.

**Creates 4 resources:** `auth0_client` (SPA), `auth0_tenant`,
`auth0_attack_protection`, `auth0_guardian`.

## Usage

```shell
terraform init
terraform apply
```

Feed `app_client_id` and `issuer_url` into your app's Auth0 SDK config.

Note that `mfa_policy = "never"` still creates the `auth0_guardian` resource - it
configures the factor as disabled rather than leaving it unmanaged. That keeps the
tenant's MFA state declarative instead of drifting to whatever the dashboard says.
