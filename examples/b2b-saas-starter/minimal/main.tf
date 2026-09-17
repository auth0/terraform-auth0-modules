module "saas" {
  source = "../../../modules/b2b-saas-starter"

  app_name        = "Acme (Dev)"
  app_callbacks   = ["http://localhost:3000/callback"]
  app_logout_urls = ["http://localhost:3000"]
  app_origins     = ["http://localhost:3000"]

  mfa_policy = "never"
}

output "app_client_id" {
  value = module.saas.app_client_id
}

output "issuer_url" {
  value = module.saas.issuer_url
}
