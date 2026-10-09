variable "parent_id" {
  description = "ID of the Nebius project (project-...) that owns the networking resources."
  type        = string
}

variable "name" {
  description = "Name prefix for the networking resources."
  type        = string
}

variable "labels" {
  description = "Labels applied to every networking resource."
  type        = map(string)
  default     = {}
}

variable "create" {
  description = "Create a new VPC network and subnet. When false, existing_subnet_id must be set."
  type        = bool
  default     = true
}

variable "existing_subnet_id" {
  description = "ID of an existing subnet (vpcsubnet-...) to use when create = false."
  type        = string
  default     = null
}

variable "private_pool_cidrs" {
  description = <<-EOT
    CIDR blocks for a dedicated private IPv4 pool attached to the new network.
    Leave empty to let the network use the project's default private pools.
  EOT
  type        = list(string)
  default     = []
}

variable "subnet_cidrs" {
  description = <<-EOT
    CIDR blocks allocated to the subnet out of the network's private pools.
    Leave empty to let the subnet use the whole network pool (use_network_pools = true).
  EOT
  type        = list(string)
  default     = []
}
