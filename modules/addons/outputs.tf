output "gpu_operator_namespace" {
  description = "Namespace of the GPU Operator release (null when not installed)."
  value       = var.gpu_operator_enabled ? helm_release.gpu_operator[0].namespace : null
}

output "gpu_operator_version" {
  description = "Installed GPU Operator chart version (null when not installed)."
  value       = var.gpu_operator_enabled ? var.gpu_operator_version : null
}

output "dynamo_namespace" {
  description = "Namespace of the Dynamo platform release (null when not installed)."
  value       = var.dynamo_enabled ? helm_release.dynamo_platform[0].namespace : null
}

output "dynamo_version" {
  description = "Installed Dynamo platform chart version (null when not installed)."
  value       = var.dynamo_enabled ? var.dynamo_version : null
}
