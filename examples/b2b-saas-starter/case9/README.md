# Case 9: Separating tenant config from app config

The same two-instance pattern as [Case 8](../case8), stripped of custom domains,
organizations, and M2M so the ownership split is the only thing on display.

- `module.main_app` owns all shared tenant configuration - session lifetimes,
  support contact, branding, MFA policy, attack protection - alongside the primary
  SPA.
- `module.admin_app` owns only its own app client, API, and roles.

**Creates 14 resources:** 6 from `main_app` and 8 from `admin_app`.

## The pattern

```hcl
module "admin_app" {
  # ...
  manage_tenant            = false
  manage_attack_protection = false
  manage_mfa               = false
}
```

This is the shape to reach for when several apps share one tenant. Tenant-wide
policy lives in one place, each app instance stays narrow, and there is no
ambiguity about which configuration wins.

Note that `main_app` here declares no `roles` or `permissions`, so it creates an
API with no RBAC scopes while `admin_app` does declare a `super_admin` role - the
two instances need not be configured symmetrically.

## Usage

```shell
terraform init
terraform apply
```

`admin_app_client_secret` is sensitive; `admin_app` is a `regular_web` client, so
it gets client credentials where a SPA would not.
