################################
# Cluster
################################

output "cluster_id" {
  description = "ID of the Managed Kubernetes cluster."
  value       = nebius_mk8s_v1_cluster.this.id
}

output "cluster_name" {
  description = "Name of the Managed Kubernetes cluster."
  value       = nebius_mk8s_v1_cluster.this.name
}

output "cluster_public_endpoint" {
  description = "Public Kubernetes API endpoint (null when public_endpoint = false)."
  value       = try(nebius_mk8s_v1_cluster.this.status.control_plane.endpoints.public_endpoint, null)
}

output "cluster_private_endpoint" {
  description = "Private Kubernetes API endpoint, reachable from inside the VPC."
  value       = try(nebius_mk8s_v1_cluster.this.status.control_plane.endpoints.private_endpoint, null)
}

output "cluster_ca_certificate" {
  description = "PEM-encoded CA certificate of the Kubernetes API."
  value       = try(nebius_mk8s_v1_cluster.this.status.control_plane.auth.cluster_ca_certificate, null)
}

output "get_credentials_command" {
  description = "Nebius CLI command that writes a kubeconfig entry for the cluster."
  value = format(
    "nebius mk8s cluster get-credentials --id %s %s",
    nebius_mk8s_v1_cluster.this.id,
    var.public_endpoint ? "--external" : "--internal",
  )
}

################################
# Networking
################################

output "network_id" {
  description = "ID of the VPC network."
  value       = module.network.network_id
}

output "subnet_id" {
  description = "ID of the subnet used by the control plane and nodes."
  value       = module.network.subnet_id
}

################################
# IAM
################################

output "node_service_account_id" {
  description = "ID of the service account the nodes run as."
  value       = module.iam.node_service_account_id
}

output "access_group_ids" {
  description = "IDs of the access groups, keyed by access_groups key."
  value       = module.iam.access_group_ids
}

################################
# Node groups
################################

output "cpu_node_group_ids" {
  description = "IDs of the CPU node groups, keyed by cpu_node_groups key."
  value       = { for k, ng in module.cpu_node_group : k => ng.id }
}

output "gpu_node_group_ids" {
  description = "IDs of the GPU node groups, keyed by gpu_node_groups key."
  value       = { for k, ng in module.gpu_node_group : k => ng.id }
}

output "gpu_cluster_ids" {
  description = "IDs of the InfiniBand GPU clusters created for GPU node groups."
  value       = { for k, c in nebius_compute_v1_gpu_cluster.this : k => c.id }
}
