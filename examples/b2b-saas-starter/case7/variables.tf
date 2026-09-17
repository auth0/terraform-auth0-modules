variable "globex_signing_cert" {
  type        = string
  sensitive   = true
  default     = null
  description = "X.509 signing certificate for the Globex SAML IdP in PEM format. If cert.pem is present in this directory it is used automatically; otherwise supply this value."
}

variable "initech_oidc_secret" {
  type        = string
  sensitive   = true
  description = "OIDC client secret for the Initech IdP. Reference from a secrets manager - do not inline."
}
