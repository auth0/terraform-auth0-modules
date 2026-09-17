# Full: every feature, two apps on one tenant

A production-shaped configuration exercising every capability the module has:
two apps on one tenant, RBAC, an M2M backend client, a custom login domain,
branding, tuned tenant and security settings, and two enterprise organizations
with mixed SSO.

**Creates 37 resources** once the custom domain is verified, or 35 on the first
apply - 29 from `main_app` (27 before verification) and 8 from `admin_app`.

If you want the same shape with commentary on each decision, read
[Case 8](../case8); this directory is organised as something you would actually
adapt, grouped by concern rather than narrated.

## What's here

`module.main_app` owns everything tenant-wide:

- SPA client with three roles and seven permissions
- Resource server with RBAC enforced
- M2M client with five Management API scopes
- Custom domain, branding, session lifetimes, support contact
- MFA set to `all-applications`, plus brute-force, suspicious-IP, and
  breached-password protection
- Two organizations - Globex over SAML, Initech over OIDC

`module.admin_app` is a `regular_web` admin dashboard with its own API and a
`super_admin` role, and delegates all three singletons to `main_app` via
`manage_* = false`.

## Before you apply

- **`custom_domain = "login.acme.com"` is a placeholder.** Point it at a host you
  control. Activation takes two applies unless Terraform manages your DNS zone -
  see [Case 4](../case4) for the manual flow and
  [custom-domain-managed-dns](../custom-domain-managed-dns) for the single-apply
  version.
- **Two IdP credentials are required:** `globex_signing_cert` (SAML certificate,
  PEM) and `initech_oidc_secret`. Neither has a default, so Terraform prompts.
  Unlike Cases 5, 7, and 8, this directory does not auto-read a `cert.pem`.
- **The `acme.com` URLs are placeholders** throughout - callbacks, logout URLs,
  origins, API identifiers, logo, and support links.

```shell
export TF_VAR_globex_signing_cert="$(cat /path/to/globex.pem)"
export TF_VAR_initech_oidc_secret="$(op read op://vault/initech/oidc-secret)"
```

## Usage

```shell
terraform init
terraform plan
terraform apply
```

Use a development tenant, and `terraform destroy` when you are done.
