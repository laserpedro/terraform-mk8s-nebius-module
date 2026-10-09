variable "cluster_id" {
  description = "ID of the Managed Kubernetes cluster (mk8scluster-...) the node group belongs to."
  type        = string
}

variable "name" {
  description = "Node group name."
  type        = string
}

variable "labels" {
  description = "Nebius resource labels for the node group object."
  type        = map(string)
  default     = {}
}

variable "k8s_version" {
  description = "Kubernetes version of the nodes (major.minor). Null follows the control plane version."
  type        = string
  default     = null
}

variable "fixed_node_count" {
  description = "Number of nodes when autoscaling is disabled."
  type        = number
  default     = 1
}

variable "autoscaling" {
  description = "Enable the cluster autoscaler for this group. Overrides fixed_node_count when set."
  type = object({
    min_node_count = number
    max_node_count = number
  })
  default = null
}

variable "strategy" {
  description = "Rollout strategy applied when the node template changes."
  type = object({
    max_surge = optional(object({
      count   = optional(number)
      percent = optional(number)
    }))
    max_unavailable = optional(object({
      count   = optional(number)
      percent = optional(number)
    }))
    drain_timeout = optional(string)
  })
  default = null
}

variable "platform" {
  description = "Compute platform, e.g. cpu-d3, cpu-e2, gpu-h100-sxm, gpu-h200-sxm, gpu-b200-sxm."
  type        = string
}

variable "preset" {
  description = "Resource preset of the platform, e.g. 16vcpu-64gb or 8gpu-128vcpu-1600gb."
  type        = string
}

variable "boot_disk_type" {
  description = "Boot disk type: NETWORK_SSD, NETWORK_SSD_NON_REPLICATED or NETWORK_SSD_IO_M3."
  type        = string
  default     = "NETWORK_SSD"
}

variable "boot_disk_size_gib" {
  description = "Boot disk size in GiB."
  type        = number
  default     = 128
}

variable "os" {
  description = "Node OS image, e.g. ubuntu22.04 or ubuntu24.04. Null uses the Nebius default for the version."
  type        = string
  default     = null
}

variable "subnet_id" {
  description = "Subnet the node network interfaces are attached to."
  type        = string
}

variable "public_ip" {
  description = "Assign a public IPv4 address to every node."
  type        = bool
  default     = false
}

variable "service_account_id" {
  description = "Service account the nodes run as."
  type        = string
  default     = null
}

variable "node_labels" {
  description = "Kubernetes labels set on every node of the group."
  type        = map(string)
  default     = {}
}

variable "taints" {
  description = "Kubernetes taints set on every node. effect is NO_SCHEDULE, PREFER_NO_SCHEDULE or NO_EXECUTE."
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = []
}

variable "preemptible" {
  description = "Run the nodes on preemptible capacity."
  type        = bool
  default     = false
}

variable "gpu_cluster_id" {
  description = "ID of a compute GPU cluster (InfiniBand fabric) to place the nodes in."
  type        = string
  default     = null
}

variable "gpu_drivers_preset" {
  description = "Use a driver-full node image with this CUDA drivers preset (e.g. cuda12). Null keeps a driverless image (install drivers via the NVIDIA GPU Operator)."
  type        = string
  default     = null
}

variable "reservation_ids" {
  description = "Capacity reservation IDs the nodes must be created from."
  type        = list(string)
  default     = []
}

variable "cloud_init_user_data" {
  description = "cloud-init user data passed to every node."
  type        = string
  default     = null
}
