output "network_id" {
  description = "ID of the VPC network the cluster is attached to."
  value       = var.create ? nebius_vpc_v1_network.this[0].id : data.nebius_vpc_v1_subnet.existing[0].network_id
}

output "subnet_id" {
  description = "ID of the subnet used by the control plane and the node groups."
  value       = var.create ? nebius_vpc_v1_subnet.this[0].id : data.nebius_vpc_v1_subnet.existing[0].id
}

output "private_pool_id" {
  description = "ID of the dedicated private IPv4 pool, if one was created."
  value       = local.create_pool ? nebius_vpc_v1_pool.private[0].id : null
}
