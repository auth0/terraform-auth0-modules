variable "globex_signing_cert" {
  type        = string
  sensitive   = true
  default     = null
  description = "X.509 signing certificate for the Globex SAML IdP in PEM format. If cert.pem is present in this directory it is used automatically; otherwise supply this value."
}
