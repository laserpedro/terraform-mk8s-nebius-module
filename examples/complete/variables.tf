variable "parent_id" {
  description = "Nebius project ID (project-...)."
  type        = string
}

variable "tenant_id" {
  description = "Nebius tenant ID (tenant-...)."
  type        = string
  default     = null
}

variable "cluster_name" {
  description = "Name of the cluster."
  type        = string
  default     = "ml-training"
}

variable "infiniband_fabric" {
  description = "InfiniBand fabric for the GPU cluster (see `nebius compute gpu-cluster` docs for your region)."
  type        = string
  default     = "fabric-3"
}

variable "ssh_public_key" {
  description = "SSH public key installed on the nodes."
  type        = string
  default     = null
}

variable "admin_member_ids" {
  description = "Account IDs added to the admins group."
  type        = list(string)
  default     = []
}

variable "viewer_member_ids" {
  description = "Account IDs added to the viewers group."
  type        = list(string)
  default     = []
}
