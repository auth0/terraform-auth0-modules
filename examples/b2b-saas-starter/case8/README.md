# Case 8: Full production setup, two apps on one tenant

The most complete example: two module instances on a single tenant, covering
everything the module offers.

- `module.main_app` owns the three tenant-level singletons, the SPA, the API with
  three-tier RBAC, the M2M backend client, branding, the custom domain, and one
  SAML organization.
- `module.admin_app` is a `regular_web` client for an admin dashboard with its own
  API and a `super_admin` role. It manages **no** tenant-level resources.

**Creates 34 resources** once the domain is verified, or 32 on the first apply -
26 from `main_app` and 8 from `admin_app`.

## The singleton problem this demonstrates

`auth0_tenant`, `auth0_attack_protection`, and `auth0_guardian` are one-per-tenant
resources. Two module instances that both manage them would fight on every apply,
each overwriting the other's settings. So the secondary instance opts out:

```hcl
module "admin_app" {
  # ...
  manage_tenant            = false
  manage_attack_protection = false
  manage_mfa               = false
}
```

Exactly one instance per tenant should own each. Getting this wrong produces
perpetual drift rather than a clean error, which is why it is worth seeing
explicitly. [Case 9](../case9) shows the same idea with less noise around it.

## Two applies for the custom domain

`main_app` sets `custom_domain` but does not manage that DNS zone, so activation
takes two applies - see [Case 4](../case4) for the full walkthrough.
`login.acme.com` is a placeholder.

## Credentials needed

`cert.pem` in this directory, or the `globex_signing_cert` variable, for the SAML
organization. The path is gitignored.

## Usage

```shell
terraform init
terraform apply
```

`main_app_m2m_client_secret` and `admin_app_client_secret` are sensitive; read
them with `terraform output -raw` into your secrets manager.
