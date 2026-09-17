# b2b-saas-starter examples

Runnable configurations for the [`b2b-saas-starter`](../../modules/b2b-saas-starter)
module. Each directory is a self-contained Terraform root that references the
module by relative path, so it exercises the code in this working tree rather
than a published version.

## Pick an example

Start with `minimal`. Move to the `caseN` directories to see one capability
added at a time, or jump to `full` for everything at once.

| Example | What it shows | Resources |
| --- | --- | --- |
| [minimal](minimal) | Smallest useful config - a SPA client for local dev, MFA off | 4 |
| [Case 1](case1) | App client only - a SPA with the module's secure defaults | 4 |
| [Case 2](case2) | Adds a protected API with RBAC: two roles, scoped permissions | 11 |
| [Case 3](case3) | Adds an M2M backend client with a Management API grant | 8 |
| [Case 4](case4) | Adds branding, a custom login domain, and three-tier RBAC | 18 |
| [Case 5](case5) | Enterprise SSO over SAML - one org, domain-based IdP routing | 11 |
| [Case 6](case6) | Enterprise SSO over OIDC - one org against an Okta tenant | 11 |
| [Case 7](case7) | Two orgs with mixed SSO - SAML and OIDC on one tenant | 14 |
| [Case 8](case8) | Production shape: two apps, two module instances, one tenant | 34 |
| [Case 9](case9) | Separating shared tenant config from per-app config | 14 |
| [full](full) | Every feature the module offers, two apps on one tenant | 37 |
| [custom-domain-managed-dns](custom-domain-managed-dns) | Custom domain verified in a **single** apply, DNS in Terraform | 8 |

Resource counts assume a completed custom-domain verification where applicable;
each example's README states its own count exactly.

## Running one

```shell
export AUTH0_DOMAIN="your-tenant.auth0.com"
export AUTH0_CLIENT_ID="..."
export AUTH0_CLIENT_SECRET="..."

cd minimal
terraform init
terraform plan
terraform apply
terraform destroy
```

The M2M application behind those credentials needs the Auth0 Management API
scopes for whatever the example creates.

## Two things that trip people up

**Custom domains usually take two applies.** Auth0 will only verify a domain
whose DNS record is already live, and with manually-managed DNS that record
cannot exist until Terraform has printed it. So verification is opt-in:
apply once to create the domain and read `dns_verification_record`, add the
record, then apply again with `enable_custom_domain_verification = true`. The
`custom_domain_next_step` output tells you which step you are on.
[custom-domain-managed-dns](custom-domain-managed-dns) shows how to collapse
this into one apply when Terraform owns the DNS zone.

**Tenant-level resources are singletons.** `auth0_tenant`,
`auth0_attack_protection`, and `auth0_guardian` exist once per tenant, so
running two module instances against one tenant requires exactly one of them to
own each. Set `manage_tenant`, `manage_attack_protection`, and `manage_mfa` to
`false` on the secondary instances - see [Case 9](case9) for the clean split and
[Case 8](case8) for the full production version.

## SAML certificates

`case5`, `case7`, and `case8` need an X.509 signing certificate. Each picks up a
`cert.pem` from its own directory automatically if present, and otherwise prompts
for the variable. Those paths are gitignored, so a real IdP certificate will not
be committed by accident. For a plan-only run, any self-signed certificate works:

```shell
openssl req -x509 -newkey rsa:2048 -nodes -keyout /dev/null \
  -out cert.pem -days 365 -subj "/CN=example"
```

## Costs

These examples create real resources in a real Auth0 tenant. Use a development
tenant, and run `terraform destroy` when finished.
