# Custom domain with Terraform-managed DNS

Every other custom-domain example takes two applies, because Auth0 will not verify
a domain whose DNS record is not live yet, and with manually-managed DNS that
record cannot exist until Terraform has printed it.

When Terraform owns the DNS zone - Route 53 here, but the pattern is identical for
Cloudflare, DigitalOcean, or Google - that constraint disappears and the whole
thing collapses into one apply.

**Creates 8 resources:** `auth0_client`, `auth0_custom_domain`,
`auth0_custom_domain_verification`, `time_sleep.dns_propagation`,
`aws_route53_record.auth0_verification`, plus the three tenant singletons.

## How the ordering works

Two inputs make the single apply safe:

```hcl
enable_custom_domain_verification = true
custom_domain_dns_record_ready    = aws_route53_record.auth0_verification.fqdn
custom_domain_propagation_wait    = "30s"
```

- `enable_custom_domain_verification` opts in to verification on this apply. It
  defaults to `false` for the manual case.
- `custom_domain_dns_record_ready` is the dependency hook. There is no
  cross-module `depends_on` for this, so passing any attribute of the record
  resource is what orders the propagation wait - and therefore verification -
  *after* the record exists. Without it nothing stops Terraform from polling Auth0
  before the record is written.

The sequence: the module creates the domain and exposes `dns_verification_record`
-> this root module writes it into Route 53 -> the module waits -> Auth0 is
polled.

## Don't set the wait to `0s`

Route 53 propagates in seconds, so `30s` is plenty - but not zero. Verification
polling has a finite retry budget (`custom_domain_verification_timeout`, default
`15m`), and starting before the just-written record is visible can burn it on
failures. A short cushion costs nothing.

## Before you apply

This example needs an AWS provider with access to a Route 53 zone, and
`data.aws_route53_zone.primary` is hardcoded to `acme.com.` - change it to a zone
you control, along with `custom_domain`.

## Usage

```shell
terraform init
terraform apply
```

`custom_domain_status` should read `ready` when the apply finishes.
