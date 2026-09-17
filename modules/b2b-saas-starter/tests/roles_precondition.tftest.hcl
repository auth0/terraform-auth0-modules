# Tests for the precondition that rejects roles/permissions when api_identifier is unset.
#
# The precondition lives on data.auth0_tenant.current (main.tf) rather than on
# auth0_role.roles / auth0_role_permission.permissions because both resources use
# for_each = {} when create_api is false, so preconditions on them never fire.

mock_provider "auth0" {
  mock_data "auth0_tenant" {
    defaults = {
      domain = "example.auth0.com"
    }
  }
}

# --- error cases ---------------------------------------------------------------

run "roles_without_api_identifier_fails" {
  command = plan

  variables {
    roles = ["admin"]
    # api_identifier intentionally omitted
  }

  expect_failures = [data.auth0_tenant.current]
}

run "permissions_without_api_identifier_fails" {
  command = plan

  variables {
    roles = ["admin"]
    permissions = {
      admin = ["read:data"]
    }
    # api_identifier intentionally omitted
  }

  expect_failures = [data.auth0_tenant.current]
}

run "permissions_alone_without_api_identifier_fails" {
  command = plan

  variables {
    # roles is empty but permissions is non-empty - should still fail
    permissions = {
      admin = ["read:data"]
    }
    # api_identifier intentionally omitted
  }

  expect_failures = [data.auth0_tenant.current]
}

run "leeway_exceeding_idle_lifetime_fails" {
  command = plan

  variables {
    refresh_token_leeway        = 999999
    refresh_token_idle_lifetime = 100
  }

  expect_failures = [data.auth0_tenant.current]
}

# --- happy paths ---------------------------------------------------------------

run "roles_with_api_identifier_succeeds" {
  command = plan

  variables {
    api_identifier = "https://api.example.com"
    api_name       = "Test API"
    roles          = ["admin", "member"]
    permissions = {
      admin  = ["read:data", "write:data"]
      member = ["read:data"]
    }
  }
}

run "empty_roles_and_permissions_without_api_identifier_succeeds" {
  command = plan

  variables {
    # No api_identifier, no roles, no permissions — valid minimal config
  }
}

run "leeway_within_idle_lifetime_succeeds" {
  command = plan

  variables {
    refresh_token_leeway        = 3
    refresh_token_idle_lifetime = 1296000
  }
}
