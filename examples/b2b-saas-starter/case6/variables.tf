variable "initech_oidc_secret" {
  type        = string
  sensitive   = true
  description = "OIDC client secret for the Initech IdP. Reference from a secrets manager - do not inline."
}
