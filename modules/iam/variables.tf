variable "parent_id" {
  description = "ID of the Nebius project (project-...) where IAM resources are created and roles are granted."
  type        = string
}

variable "tenant_id" {
  description = "ID of the Nebius tenant (tenant-...). Only required when node_service_account_tenant_groups is non-empty."
  type        = string
  default     = null
}

variable "name" {
  description = "Name prefix for the IAM resources."
  type        = string
}

variable "create_node_service_account" {
  description = "Create a dedicated service account that the cluster nodes run as."
  type        = bool
  default     = true
}

variable "existing_node_service_account_id" {
  description = "ID of an existing service account (serviceaccount-...) for the nodes. Used when create_node_service_account = false."
  type        = string
  default     = null
}

variable "node_service_account_roles" {
  description = <<-EOT
    Roles granted on the project to the node service account, through a dedicated IAM group.
    Nodes typically need to pull images from Nebius Container Registry and attach storage.
  EOT
  type        = list(string)
  default     = ["editor"]
}

variable "node_service_account_tenant_groups" {
  description = "Names of existing tenant-level groups (e.g. \"editors\") the node service account is added to."
  type        = list(string)
  default     = []
}

variable "access_groups" {
  description = <<-EOT
    IAM groups to create for human or workload access to the project and its cluster.
    Each group gets the listed roles on the project and the listed members
    (user accounts "useraccount-..." or service accounts "serviceaccount-...").
  EOT
  type = map(object({
    roles      = list(string)
    member_ids = optional(list(string), [])
  }))
  default = {}
}
