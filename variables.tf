################################
# General
################################

variable "parent_id" {
  description = "ID of the Nebius project (project-...) where every resource is created."
  type        = string

  validation {
    condition     = startswith(var.parent_id, "project-")
    error_message = "parent_id must be a project ID starting with \"project-\"."
  }
}

variable "tenant_id" {
  description = "ID of the Nebius tenant (tenant-...). Only needed when iam.node_service_account_tenant_groups is set."
  type        = string
  default     = null

  validation {
    condition     = var.tenant_id == null || startswith(coalesce(var.tenant_id, "tenant-"), "tenant-")
    error_message = "tenant_id must start with \"tenant-\"."
  }
}

variable "name" {
  description = "Cluster name, also used as a prefix for every resource the module creates."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,40}[a-z0-9]$", var.name))
    error_message = "name must be 3-42 chars of lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "labels" {
  description = "Nebius labels applied to every resource the module creates."
  type        = map(string)
  default     = {}
}

################################
# Networking layer
################################

variable "network" {
  description = <<-EOT
    Networking layer.
      create             - create a VPC network + subnet (true) or reuse existing_subnet_id (false).
      existing_subnet_id - subnet to reuse when create = false.
      private_pool_cidrs - CIDRs of a dedicated private pool for the new network; empty = project default pools.
      subnet_cidrs       - CIDRs carved out of the network pools for the subnet; empty = use the whole network pool.
  EOT
  type = object({
    create             = optional(bool, true)
    existing_subnet_id = optional(string)
    private_pool_cidrs = optional(list(string), [])
    subnet_cidrs       = optional(list(string), [])
  })
  default = {}

  validation {
    condition     = var.network.create || var.network.existing_subnet_id != null
    error_message = "network.existing_subnet_id is required when network.create = false."
  }

  validation {
    condition = alltrue([
      for cidr in concat(var.network.private_pool_cidrs, var.network.subnet_cidrs) : can(cidrhost(cidr, 0))
    ])
    error_message = "network.private_pool_cidrs and network.subnet_cidrs must be valid IPv4 CIDR blocks."
  }
}

################################
# IAM layer
################################

variable "iam" {
  description = <<-EOT
    IAM layer for the nodes.
      create_node_service_account        - create a service account the nodes run as.
      existing_node_service_account_id   - reuse this service account instead (create_node_service_account = false).
      node_service_account_roles         - project roles granted to the node service account via a dedicated group.
      node_service_account_tenant_groups - existing tenant groups (by name) the service account joins, e.g. ["editors"].
  EOT
  type = object({
    create_node_service_account        = optional(bool, true)
    existing_node_service_account_id   = optional(string)
    node_service_account_roles         = optional(list(string), ["editor"])
    node_service_account_tenant_groups = optional(list(string), [])
  })
  default = {}

  validation {
    condition     = length(var.iam.node_service_account_tenant_groups) == 0 || var.iam.create_node_service_account
    error_message = "iam.node_service_account_tenant_groups requires iam.create_node_service_account = true."
  }
}

variable "access_groups" {
  description = <<-EOT
    IAM groups created for users/workloads that operate the cluster, keyed by a short name
    (the group is named "<name>-<key>"). Each grants its roles on the project to its members.
    Example: { admins = { roles = ["editor"], member_ids = ["useraccount-..."] } }
  EOT
  type = map(object({
    roles      = list(string)
    member_ids = optional(list(string), [])
  }))
  default = {}
}

################################
# Control plane
################################

variable "k8s_version" {
  description = "Kubernetes version (major.minor) of the control plane and, by default, of the node groups."
  type        = string
  default     = "1.31"

  validation {
    condition     = can(regex("^1\\.[0-9]+$", var.k8s_version))
    error_message = "k8s_version must look like \"1.31\"."
  }
}

variable "public_endpoint" {
  description = "Expose the Kubernetes API on a public IP address."
  type        = bool
  default     = true
}

variable "etcd_cluster_size" {
  description = "Number of etcd members of the control plane: 1 (dev) or 3 (highly available)."
  type        = number
  default     = 3

  validation {
    condition     = contains([1, 3], var.etcd_cluster_size)
    error_message = "etcd_cluster_size must be 1 or 3."
  }
}

variable "service_cidrs" {
  description = "CIDRs for Kubernetes Services (ClusterIP). Null uses the Nebius default."
  type        = list(string)
  default     = null
}

################################
# Node access
################################

variable "ssh_user_name" {
  description = "Linux user created on every node when ssh_public_key is set."
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key" {
  description = "SSH public key authorised for ssh_user_name on every node. Null disables SSH user provisioning."
  type        = string
  default     = null
}

################################
# Node groups
################################

variable "cpu_node_groups" {
  description = <<-EOT
    CPU node groups keyed by short name (the group is named "<name>-<key>").
    Set autoscaling to enable the cluster autoscaler; otherwise fixed_node_count nodes are kept.
  EOT
  type = map(object({
    platform           = optional(string, "cpu-d3")
    preset             = optional(string, "16vcpu-64gb")
    fixed_node_count   = optional(number, 2)
    autoscaling        = optional(object({ min_node_count = number, max_node_count = number }))
    boot_disk_type     = optional(string, "NETWORK_SSD")
    boot_disk_size_gib = optional(number, 128)
    os                 = optional(string)
    k8s_version        = optional(string)
    public_ip          = optional(bool, false)
    preemptible        = optional(bool, false)
    node_labels        = optional(map(string), {})
    taints             = optional(list(object({ key = string, value = string, effect = string })), [])
    cloud_init         = optional(string)
    strategy = optional(object({
      max_surge       = optional(object({ count = optional(number), percent = optional(number) }))
      max_unavailable = optional(object({ count = optional(number), percent = optional(number) }))
      drain_timeout   = optional(string)
    }))
  }))
  default = {
    system = {}
  }

  validation {
    condition     = length(var.cpu_node_groups) > 0
    error_message = "At least one CPU node group is required to run cluster system workloads."
  }
}

variable "gpu_node_groups" {
  description = <<-EOT
    GPU node groups keyed by short name (the group is named "<name>-<key>").
      infiniband_fabric  - create a GPU cluster on this InfiniBand fabric (e.g. fabric-3) for the group.
      gpu_cluster_id     - or place the nodes into an existing GPU cluster.
      gpu_drivers_preset - use a driver-full image (e.g. "cuda12"); null = driverless, install the GPU Operator.
      gpu_taint          - add the nvidia.com/gpu=true:NoSchedule taint so only GPU workloads land there.
  EOT
  type = map(object({
    platform           = optional(string, "gpu-h100-sxm")
    preset             = optional(string, "8gpu-128vcpu-1600gb")
    fixed_node_count   = optional(number, 1)
    autoscaling        = optional(object({ min_node_count = number, max_node_count = number }))
    boot_disk_type     = optional(string, "NETWORK_SSD")
    boot_disk_size_gib = optional(number, 512)
    os                 = optional(string)
    k8s_version        = optional(string)
    public_ip          = optional(bool, false)
    preemptible        = optional(bool, false)
    node_labels        = optional(map(string), {})
    taints             = optional(list(object({ key = string, value = string, effect = string })), [])
    gpu_taint          = optional(bool, true)
    infiniband_fabric  = optional(string)
    gpu_cluster_id     = optional(string)
    gpu_drivers_preset = optional(string)
    reservation_ids    = optional(list(string), [])
    cloud_init         = optional(string)
    strategy = optional(object({
      max_surge       = optional(object({ count = optional(number), percent = optional(number) }))
      max_unavailable = optional(object({ count = optional(number), percent = optional(number) }))
      drain_timeout   = optional(string)
    }))
  }))
  default = {}

  validation {
    condition = alltrue([
      for ng in values(var.gpu_node_groups) : !(ng.infiniband_fabric != null && ng.gpu_cluster_id != null)
    ])
    error_message = "A GPU node group can set infiniband_fabric or gpu_cluster_id, not both."
  }

  validation {
    condition = alltrue([
      for ng in values(var.gpu_node_groups) :
      (ng.infiniband_fabric == null && ng.gpu_cluster_id == null) || startswith(ng.preset, "8gpu-")
    ])
    error_message = "InfiniBand GPU clusters require an 8-GPU preset (8gpu-...)."
  }
}
