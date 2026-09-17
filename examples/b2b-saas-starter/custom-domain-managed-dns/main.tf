# Custom domain with Terraform-managed DNS - single apply
#
# When your DNS zone lives in the same Terraform (here: Route 53), the manual
# two-step apply is unnecessary. Terraform creates the Auth0 custom domain, reads
# the verification record from the module's dns_verification_record output, writes
# it into your zone, and Auth0 verifies it - all in one apply.
#
# Two inputs make that safe:
#   enable_custom_domain_verification = true
#     Opts in to verification on this apply. The default is false, for the manual
#     DNS case where the record cannot exist yet on the first apply.
#   custom_domain_dns_record_ready = <any attribute of the record resource>
#     Passes the dependency explicitly, since there is no cross-module
#     depends_on: the module's propagation wait, and therefore verification, is
#     ordered after the record resource is created.
#
# Sequence: the module creates the domain and exposes the record -> this root
# module writes it into Route 53 -> the module waits custom_domain_propagation_wait
# -> Auth0 is polled. Route 53 propagates in seconds, so a short wait is enough.
# Avoid "0s" here: verification can start before the just-written record is
# visible and spend its retry budget.
#
# Expected resources: 8
#   auth0_client (SPA)
#   auth0_tenant
#   auth0_attack_protection
#   auth0_guardian
#   auth0_custom_domain
#   auth0_custom_domain_verification
#   time_sleep.dns_propagation
#   aws_route53_record.auth0_verification

module "saas" {
  source = "../../../modules/b2b-saas-starter"

  app_name        = "Acme"
  app_callbacks   = ["https://app.acme.com/callback"]
  app_logout_urls = ["https://app.acme.com"]
  app_origins     = ["https://app.acme.com"]

  custom_domain = "login.acme.com"

  # DNS is managed below, in this same run, so verification can run on the first
  # apply - ordered after the record via custom_domain_dns_record_ready.
  enable_custom_domain_verification = true
  custom_domain_dns_record_ready    = aws_route53_record.auth0_verification.fqdn

  # Route 53 propagates in seconds, so a short cushion (not 0s) is enough to keep
  # the first verification poll from racing the record just created.
  custom_domain_propagation_wait = "30s"
}

# The DNS zone you control. Adjust to your provider (Cloudflare, DigitalOcean,
# Google, etc.); the pattern is identical - feed dns_verification_record into a
# managed record resource, then feed that resource back in as the ready signal.
data "aws_route53_zone" "primary" {
  name = "acme.com."
}

resource "aws_route53_record" "auth0_verification" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = module.saas.dns_verification_record.name # FQDN of the record host
  type    = module.saas.dns_verification_record.type # "CNAME"
  ttl     = 60
  records = [module.saas.dns_verification_record.value]
}

output "issuer_url" {
  description = "Custom-domain issuer once verified; tenant URL until then."
  value       = module.saas.issuer_url
}

output "custom_domain_status" {
  value = module.saas.custom_domain_status
}
