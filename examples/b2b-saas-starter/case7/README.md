# Case 7: Two organizations, mixed SSO

Two enterprise organizations on one tenant, one authenticating over SAML (Globex)
and one over OIDC (Initech). This is the realistic multi-tenant B2B shape: each
customer brings their own IdP, and you cannot dictate the protocol.

**Creates 14 resources** once the domain is verified, or 12 on the first apply.
That is `auth0_client`, `auth0_resource_server`, `auth0_organization` x2,
`auth0_connection` x2 (one SAML, one OIDC), `auth0_organization_connection` x2,
`auth0_custom_domain`, the three tenant singletons, and on apply 2 the two
verification resources.

## Why this works from one list

Both organizations are entries in the same `organizations` list, each with its own
`connection` block whose `type` selects the protocol. The module keys its
`for_each` off organization names via `nonsensitive()`, which is what lets the list
carry sensitive IdP credentials without Terraform refusing to iterate.

Each org routes on its own `domain_aliases`, so `@globex.com` reaches the SAML IdP
and `@initech.com` reaches Okta, through a single login page.

## Credentials needed

- `cert.pem` in this directory, or the `globex_signing_cert` variable - the SAML
  signing certificate (see [Case 5](../case5) for generating a throwaway one).
- `initech_oidc_secret` - the OIDC client secret, required, no default.

Both `cert.pem` paths are gitignored.

## Two applies for the custom domain

Same flow as [Case 4](../case4). `login.acme.com` is a placeholder.

## Usage

```shell
terraform init
terraform apply
```
