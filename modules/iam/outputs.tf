output "node_service_account_id" {
  description = "ID of the service account the nodes run as (null if none)."
  value       = local.node_service_account_id

  # Consumers (node groups) must not start before the account holds its permissions.
  depends_on = [
    nebius_iam_v1_group_membership.nodes,
    nebius_iam_v1_group_membership.tenant,
  ]
}

output "node_group_id" {
  description = "ID of the IAM group holding the node service account's project roles."
  value       = length(nebius_iam_v1_group.nodes) > 0 ? nebius_iam_v1_group.nodes[0].id : null
}

output "access_group_ids" {
  description = "IDs of the access groups, keyed by the access_groups map key."
  value       = { for k, g in nebius_iam_v1_group.access : k => g.id }
}
