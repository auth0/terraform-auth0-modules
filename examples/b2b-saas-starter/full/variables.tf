variable "initech_oidc_secret" {
  type        = string
  sensitive   = true
  description = "OIDC client secret for the Initech IdP. Reference from a secrets manager - do not inline."
}

variable "globex_signing_cert" {
  type        = string
  sensitive   = true
  description = "X.509 signing certificate for the Globex SAML IdP in PEM format. Use file(\"path/to/cert.pem\") to load from disk, or reference from a secrets manager."
}
