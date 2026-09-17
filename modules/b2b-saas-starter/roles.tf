resource "auth0_role" "roles" {
  for_each = local.create_api ? toset(var.roles) : toset([])

  name = each.value
}

locals {
  # Expand permissions map into a flat list of {role, permission} pairs for for_each.
  # e.g. { admin = ["read:data", "write:data"] } -> [{role="admin", permission="read:data"}, ...]
  role_permissions_flat = flatten([
    for role, perms in var.permissions : [
      for perm in perms : {
        role       = role
        permission = perm
      }
    ]
  ])

  role_permissions_map = {
    for entry in local.role_permissions_flat :
    "${entry.role}:${entry.permission}" => entry
  }
}

resource "auth0_role_permission" "permissions" {
  for_each = local.create_api ? local.role_permissions_map : {}

  role_id                    = auth0_role.roles[each.value.role].id
  resource_server_identifier = auth0_resource_server.api[0].identifier
  permission                 = each.value.permission

  # Scopes must exist on the resource server before they can be assigned to a role.
  # Without this, Auth0 returns 404 when permissions and scopes are created in the same apply.
  depends_on = [auth0_resource_server_scopes.api]

  lifecycle {
    precondition {
      condition     = contains(var.roles, each.value.role)
      error_message = "permissions key \"${each.value.role}\" is not in the `roles` list. Add it to `roles` first. Example: roles = [\"${each.value.role}\"]"
    }
  }
}
