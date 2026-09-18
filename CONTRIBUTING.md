# Contributing

Thank you for contributing to the Auth0 Terraform modules.

## Repository layout

```
modules/<name>/        the module itself, plus its own README
examples/<name>/       runnable configurations for that module, one per scenario
```

A new module means a new `modules/<name>/` directory with its own README, plus at
least a `minimal` and a `full` example under `examples/<name>/`. Examples must
reference the module by relative path (`../../../modules/<name>`) so CI validates
the code in the tree, not a published version.

Everything else - `.tflint.hcl`, `.terraform-docs.yml`, CI, `CHANGELOG.md`, this
file - is shared across all modules and stays at the repo root.

## Prerequisites

- Terraform >= 1.3.0
- An Auth0 tenant with a Machine-to-Machine application authorised for the **Auth0 Management API** (grant all Management API scopes)
- Provider credentials exported as environment variables:

```shell
export AUTH0_DOMAIN="your-tenant.auth0.com"
export AUTH0_CLIENT_ID="..."
export AUTH0_CLIENT_SECRET="..."
```

## Running examples locally

Each example under `examples/<module>/` is a self-contained Terraform
configuration. To test one:

```shell
cd examples/b2b-saas-starter/case2
terraform init
terraform plan
terraform apply
terraform destroy
```

For `b2b-saas-starter`, the SAML cases (`case5`, `case7`, `case8`) automatically pick up a `cert.pem` file in the same directory if present; otherwise Terraform prompts for the value.

## Coding conventions

- **Presence-driven creation** - a resource is created only when its trigger variable is non-null or non-empty. Do not add `enabled` booleans for resources that can simply be omitted.
- **Flat modules** - each module under `modules/` is self-contained with no nested sub-modules. Its resources live in top-level `.tf` files grouped by concern (`client.tf`, `api.tf`, `organizations.tf`, etc.).
- **No cross-module dependencies** - modules must not reference each other by relative path. Compose them in the caller's configuration instead.
- **Comments** - only when the *why* is non-obvious. Never explain what the code does; well-named identifiers do that. Never reference the current PR or issue number in a comment.
- **Formatting** - run `terraform fmt -recursive` before committing. The CI `fmt` job will fail the PR if any file is unformatted.
- **Sensitive values** - never use sensitive variables as `for_each` keys. Use `nonsensitive()` on name-only derived sets when iteration over objects containing sensitive fields is unavoidable.

## Submitting a pull request

1. Fork the repo and create a branch from `main`.
2. Make your changes and run `terraform fmt -recursive` from the repo root.
3. Run `terraform validate` on every module and example, the same way CI does:
   ```shell
   for d in $(find modules examples -name '*.tf' -exec dirname {} \; | sort -u); do
     terraform -chdir="$d" init -backend=false && terraform -chdir="$d" validate
   done
   ```
4. Open a PR using the provided template. Link the relevant case example in the description.
5. Ensure all CI checks pass (fmt, validate, tflint, docs).

## Reporting issues

Open a GitHub Issue and include:

- `terraform version` output
- Provider version (`auth0/auth0` and `hashicorp/time`)
- Module version or commit SHA
- Minimal HCL that reproduces the issue
- Full error output

Do not include real Auth0 credentials, tenant domains, or client secrets in issue reports.

## Releasing

1. Update `CHANGELOG.md` - move items from `[Unreleased]` to a new `[X.Y.Z]` heading with today's date.
2. Commit: `git commit -m "chore: release vX.Y.Z"`
3. Tag: `git tag vX.Y.Z`
4. Push: `git push origin main --tags`

The Terraform Registry webhook picks up the tag and publishes the new version automatically. Tags must be valid semver (e.g. `v0.1.0`, `v0.2.0`). No `v` prefix variants - the Registry expects the `v` prefix.

One tag releases every module in the repo, so a breaking change in any single module bumps the major version for all of them. Group the changelog entries by module (`### b2b-saas-starter`) so consumers can tell which changes affect them.
