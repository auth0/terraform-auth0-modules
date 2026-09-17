resource "auth0_guardian" "this" {
  count = var.manage_mfa ? 1 : 0

  policy        = var.mfa_policy
  otp           = var.mfa_otp
  email         = var.mfa_email
  recovery_code = var.mfa_recovery_code
}
