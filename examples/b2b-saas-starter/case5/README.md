# Case 5: Enterprise SSO over SAML

Provisions one enterprise organization backed by a SAML 2.0 identity provider.
Users arriving with a `globex.com` email are routed to the Globex IdP at login,
and membership is assigned automatically on first successful login.

**Creates 11 resources** once the domain is verified, or 9 on the first apply.
That is `auth0_client`, `auth0_resource_server`, `auth0_organization`,
`auth0_connection` (SAML), `auth0_organization_connection`,
`auth0_custom_domain`, the three tenant singletons, and on apply 2
`auth0_custom_domain_verification` plus `time_sleep.dns_propagation`.

## The SAML certificate

This example needs an X.509 signing certificate from the IdP. It reads `cert.pem`
from this directory automatically if present, and otherwise prompts for
`globex_signing_cert`. `cert.pem` is gitignored, so a real certificate will not be
committed by accident.

For a plan-only run, any self-signed certificate is fine:

```shell
openssl req -x509 -newkey rsa:2048 -nodes -keyout /dev/null \
  -out cert.pem -days 365 -subj "/CN=example"
```

Real SSO of course requires the actual certificate from Globex's IdP, along with
a `sign_in_endpoint` that resolves.

## Domain-based routing

```hcl
connection = {
  type             = "samlp"
  domain_aliases   = ["globex.com"]
  sign_in_endpoint = "https://idp.globex.com/sso"
  signing_cert     = local.globex_signing_cert
}
```

`domain_aliases` is what makes Home Realm Discovery work: Auth0 matches the email
domain a user types against these aliases and forwards them to the right IdP,
rather than showing a username/password form.

## Two applies for the custom domain

Same flow as [Case 4](../case4) - apply once, add the record from
`dns_verification_record`, then apply again with
`enable_custom_domain_verification = true`. `login.acme.com` is a placeholder;
point it at a host you control.

## Usage

```shell
terraform init
terraform apply
```
