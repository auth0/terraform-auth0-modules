# Case 3: M2M backend client

Adds a machine-to-machine client granted access to the Auth0 Management API. Use
this when your backend needs to manage users, organizations, or roles
programmatically - post-signup hooks, org member provisioning, admin tooling.

**Creates 8 resources:** `auth0_client` x2 (SPA + M2M),
`auth0_client_credentials` (M2M), `auth0_resource_server`, `auth0_client_grant`
(M2M -> Management API), plus the three tenant singletons.

No roles or permissions are declared here, so no `auth0_role` resources appear -
the API exists but carries no RBAC scopes. See [Case 2](../case2) for that.

## Scope selection

```hcl
m2m_management_api_scopes = [
  "read:users",
  "update:users",
  "create:organization_members",
  "delete:organization_members",
  "read:organizations",
]
```

A non-empty list is what creates the M2M client. Grant only the scopes your
backend actually calls - this credential can administer the whole tenant, so
every extra scope widens the blast radius if it leaks.

## Handling the secret

`m2m_client_secret` is a sensitive output. It will still be written to state in
plaintext, so use a remote backend with encryption at rest, and read the value
into your secrets manager rather than copying it around:

```shell
terraform output -raw m2m_client_secret
```

## Usage

```shell
terraform init
terraform apply
```
