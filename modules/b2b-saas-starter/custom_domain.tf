resource "auth0_custom_domain" "this" {
  count = local.create_custom_domain ? 1 : 0

  domain = var.custom_domain
  type   = "auth0_managed_certs"
}

# Verification is a separate, opt-in step because Auth0 only verifies a domain
# whose DNS record is already live - and when DNS is managed by hand, that record
# cannot be created until its values have been read from the
# dns_verification_record output. Terraform prints outputs only after a
# successful apply, so verifying in the same apply that creates the domain would
# either fail or sit in a long poll, leaving the record values unseen.
#
#   Apply 1: enable_custom_domain_verification = false (default)
#            -> domain created, record values shown in the outputs
#   Manual:  add the record, run dns_verification_command until it resolves
#   Apply 2: enable_custom_domain_verification = true
#            -> Auth0 verifies and activates the domain
#
# One apply is enough when the DNS record lives in the same run: enable
# verification up front and pass custom_domain_dns_record_ready so the wait and
# verification are ordered after that record. See
# examples/custom-domain-managed-dns.

# Give DNS time to propagate before Auth0 is polled. The provider polls every
# ~10s, so without a cushion the first polls run before the record is visible and
# spend the retry budget. Match custom_domain_propagation_wait to your DNS TTL.
resource "time_sleep" "dns_propagation" {
  count = local.verify_custom_domain ? 1 : 0

  create_duration = var.custom_domain_propagation_wait

  # Re-wait if the record this run manages is replaced, and force this sleep to
  # start only after that record exists.
  triggers = {
    dns_record_ready = coalesce(var.custom_domain_dns_record_ready, "unmanaged")
  }

  depends_on = [auth0_custom_domain.this]
}

# Tells Auth0 to check DNS and activate the domain. The record from
# dns_verification_record must already be resolvable.
resource "auth0_custom_domain_verification" "this" {
  count = local.verify_custom_domain ? 1 : 0

  custom_domain_id = auth0_custom_domain.this[0].id

  timeouts {
    create = var.custom_domain_verification_timeout
  }

  depends_on = [time_sleep.dns_propagation]
}
