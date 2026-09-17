# Case 6: Enterprise SSO over OIDC

The OIDC counterpart to [Case 5](../case5). One enterprise organization backed by
an OIDC identity provider (an Okta tenant here), with users from `initech.com`
routed to it at login and membership assigned on first login.

**Creates 11 resources** once the domain is verified, or 9 on the first apply.
Same shape as Case 5, with `auth0_connection` configured for OIDC instead of SAML.

## OIDC vs SAML configuration

```hcl
connection = {
  type           = "oidc"
  domain_aliases = ["initech.com"]
  client_id      = "abc123"
  client_secret  = var.initech_oidc_secret
  discovery_url  = "https://initech.okta.com/.well-known/openid-configuration"
}
```

`discovery_url` is the practical advantage over SAML: endpoints and signing keys
are fetched from the IdP's well-known document, so there is no certificate to
paste in and no manual rotation when the IdP rolls its keys.

Scopes default to `["openid", "profile", "email"]` and can be overridden per
organization.

## The client secret

`initech_oidc_secret` is required and has no default, so Terraform prompts if you
do not supply it. Pass it from a secrets manager rather than inlining it:

```shell
export TF_VAR_initech_oidc_secret="$(op read op://vault/initech/oidc-secret)"
```

## Two applies for the custom domain

Same flow as [Case 4](../case4). `login.acme.com` is a placeholder - point
`custom_domain` at a host you control.

## Usage

```shell
terraform init
terraform apply
```
