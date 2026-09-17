# Case 4: Branding, custom domain, and three-tier RBAC

Adds tenant branding (logo and colors), a custom login domain, and a third role
tier on top of [Case 2](../case2).

**Creates 18 resources** once the domain is verified, or 16 on the first apply -
the two verification resources land only when
`enable_custom_domain_verification = true`. That is `auth0_client`,
`auth0_resource_server`, `auth0_resource_server_scopes`, `auth0_role` x3,
`auth0_role_permission` x5, `auth0_custom_domain`, `auth0_branding`, the three
tenant singletons, and on apply 2 `auth0_custom_domain_verification` plus
`time_sleep.dns_propagation`.

## This example needs two applies

Auth0 only verifies a domain whose DNS record is already live, and with
manually-managed DNS that record cannot exist until Terraform has told you what it
is. So verification is opt-in:

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

# Apply 2 - opt in to verification.
$ terraform apply -var enable_custom_domain_verification=true
```

`custom_domain_next_step` tells you which step you are on at any point.

`login.acme.com` is a placeholder - point `custom_domain` at a host you actually
control or verification can never succeed. If Terraform manages your DNS zone,
[custom-domain-managed-dns](../custom-domain-managed-dns) does this in one apply.

## Don't configure backends from `issuer_url` too early

`issuer_url` returns the *tenant* URL until the domain reports `ready`, then the
custom-domain URL. That is deliberate: Auth0 keeps issuing tokens with the tenant
`iss` until verification completes, so a backend configured from the custom domain
early would reject every token on an issuer mismatch.

## Usage

```shell
terraform init
terraform apply
```
