output "cluster_id" {
  value = module.mk8s.cluster_id
}

output "get_credentials_command" {
  value = module.mk8s.get_credentials_command
}

output "node_group_ids" {
  value = merge(module.mk8s.cpu_node_group_ids, module.mk8s.gpu_node_group_ids)
}
