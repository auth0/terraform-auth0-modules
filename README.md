# terraform-auth0-modules

A collection of opinionated Terraform modules for Auth0. Each module lives in
its own directory under [`modules/`](modules/) and is versioned and released
together with the rest of the repository.

## Available modules

| Module | Description |
| --- | --- |
| [b2b-saas-starter](modules/b2b-saas-starter) | A complete B2B SaaS identity setup: app client, API with RBAC, roles and permissions, M2M backend client, tenant security, MFA, attack protection, branding, custom login domain, and enterprise SSO organizations (SAML / OIDC). |

## Usage

Modules are published to the Terraform Registry from this repository, so each one
is addressed with the `//modules/<name>` submodule syntax:

```hcl
module "b2b_saas" {
  source  = "auth0/modules/auth0//modules/b2b-saas-starter"
  version = "~> 1.0"

  app_name        = "Acme"
  app_callbacks   = ["https://app.acme.com/callback"]
  app_logout_urls = ["https://app.acme.com"]
  app_origins     = ["https://app.acme.com"]

  api_name       = "Acme API"
  api_identifier = "https://api.acme.com"
}
```

Always pin `version` - the modules in this repo share a single release tag, so an
unpinned source picks up changes to modules you did not intend to upgrade.

Each module documents its own inputs and outputs in its README.

## Repository layout

```
modules/<name>/        the module itself, plus its own README
examples/<name>/       runnable configurations for that module, one per scenario
```

Examples reference the module by relative path (`../../../modules/<name>`) so
they always exercise the code in the working tree rather than a published
version. See [`examples/b2b-saas-starter/`](examples/b2b-saas-starter/) for
scenarios ranging from a minimal dev setup to a full multi-app production tenant
with mixed SSO.

## Provider credentials

Every module in this repo talks to the Auth0 Management API. Configure the
provider with a Machine-to-Machine application authorised for the Management API:

```shell
export AUTH0_DOMAIN="your-tenant.auth0.com"
export AUTH0_CLIENT_ID="..."
export AUTH0_CLIENT_SECRET="..."
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for local development, conventions, and
the release process. Changes are recorded in [CHANGELOG.md](CHANGELOG.md).

## Support

Generated with help from the ODF tooling. For support see the
[ODF Service Desk](https://oktainc.atlassian.net/wiki/spaces/ESS/pages/701930944/Okta+Developer+Foundations+Service+Desk)
or [#odf-servicedesk](https://okta.enterprise.slack.com/archives/C097LNQ2TFA).

## License

[Apache License 2.0](LICENSE)

Copyright 2026 Okta, Inc.
Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at: http://www.apache.org/licenses/LICENSE-2.0

