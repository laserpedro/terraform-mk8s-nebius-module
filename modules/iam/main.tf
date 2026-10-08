locals {
  manage_node_sa = var.create_node_service_account

  node_service_account_id = (
    local.manage_node_sa
    ? nebius_iam_v1_service_account.nodes[0].id
    : var.existing_node_service_account_id
  )

  node_role_grants = local.manage_node_sa ? toset(var.node_service_account_roles) : toset([])

  access_group_roles = merge([
    for group, cfg in var.access_groups : {
      for role in cfg.roles : "${group}/${role}" => { group = group, role = role }
    }
  ]...)

  access_group_members = merge([
    for group, cfg in var.access_groups : {
      for member in cfg.member_ids : "${group}/${member}" => { group = group, member = member }
    }
  ]...)
}

################################
# Node group service account
################################

resource "nebius_iam_v1_service_account" "nodes" {
  count = local.manage_node_sa ? 1 : 0

  parent_id = var.parent_id
  name      = "${var.name}-nodes-sa"
}

# Roles are granted to a group scoped to this cluster rather than to the
# service account directly, so permissions can be audited and revoked in one place.
resource "nebius_iam_v1_group" "nodes" {
  count = length(local.node_role_grants) > 0 ? 1 : 0

  parent_id = var.parent_id
  name      = "${var.name}-nodes"
}

resource "nebius_iam_v1_access_permit" "nodes" {
  for_each = local.node_role_grants

  parent_id   = nebius_iam_v1_group.nodes[0].id
  resource_id = var.parent_id
  role        = each.value
}

resource "nebius_iam_v1_group_membership" "nodes" {
  count = length(local.node_role_grants) > 0 ? 1 : 0

  parent_id = nebius_iam_v1_group.nodes[0].id
  member_id = nebius_iam_v1_service_account.nodes[0].id

  depends_on = [nebius_iam_v1_access_permit.nodes]
}

data "nebius_iam_v1_group" "tenant" {
  for_each = local.manage_node_sa ? toset(var.node_service_account_tenant_groups) : toset([])

  name      = each.value
  parent_id = var.tenant_id

  lifecycle {
    precondition {
      condition     = var.tenant_id != null
      error_message = "tenant_id must be set to look up tenant groups."
    }
  }
}

resource "nebius_iam_v1_group_membership" "tenant" {
  for_each = data.nebius_iam_v1_group.tenant

  parent_id = each.value.id
  member_id = nebius_iam_v1_service_account.nodes[0].id
}

################################
# Access groups
################################

resource "nebius_iam_v1_group" "access" {
  for_each = var.access_groups

  parent_id = var.parent_id
  name      = "${var.name}-${each.key}"
}

resource "nebius_iam_v1_access_permit" "access" {
  for_each = local.access_group_roles

  parent_id   = nebius_iam_v1_group.access[each.value.group].id
  resource_id = var.parent_id
  role        = each.value.role
}

resource "nebius_iam_v1_group_membership" "access" {
  for_each = local.access_group_members

  parent_id = nebius_iam_v1_group.access[each.value.group].id
  member_id = each.value.member

  depends_on = [nebius_iam_v1_access_permit.access]
}
