# Case 2: Resource server and RBAC

Adds a protected API to the app client from [minimal](../minimal), with two roles
and scoped permissions.

RBAC is a fixed opinion of this module: `enforce_policies = true` and
`token_dialect = "access_token_authz"` are always set, so roles and permissions
appear in every access token. An API without RBAC silently issues tokens carrying
no authorization claims at all, which is a subtle way to ship a security hole.

**Creates 11 resources:** `auth0_client` (SPA), `auth0_resource_server`,
`auth0_resource_server_scopes`, `auth0_role` x2 (admin, member),
`auth0_role_permission` x3, plus the three tenant singletons.

## The permissions model

```hcl
roles = ["admin", "member"]
permissions = {
  admin  = ["read:data", "write:data"]
  member = ["read:data"]
}
```

`roles` declares them; `permissions` maps each to its scopes. Every key in
`permissions` must appear in `roles` - the module validates this, so a typo fails
at plan time rather than producing a role with no permissions.

## Usage

```shell
terraform init
terraform apply
```

Validate the resulting tokens against `issuer_url` and the `api_identifier`
audience.
