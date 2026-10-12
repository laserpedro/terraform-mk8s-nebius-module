################################
# NVIDIA GPU Operator
################################

variable "gpu_operator_enabled" {
  description = "Install the NVIDIA GPU Operator."
  type        = bool
  default     = true
}

variable "gpu_operator_version" {
  description = "Version of the nvidia/gpu-operator Helm chart."
  type        = string
  default     = "v26.7.1"
}

variable "gpu_operator_namespace" {
  description = "Namespace of the GPU Operator release."
  type        = string
  default     = "gpu-operator"
}

variable "gpu_operator_install_driver" {
  description = <<-EOT
    Enable the GPU Operator driver DaemonSet. Needed when at least one GPU node group runs a driverless image.
    Nodes with preinstalled drivers opt out individually through the nvidia.com/gpu.deploy.driver=false label.
  EOT
  type        = bool
  default     = false
}

variable "gpu_operator_install_toolkit" {
  description = <<-EOT
    Enable the NVIDIA Container Toolkit DaemonSet. Needed on driverless nodes; nodes whose image already
    configures the NVIDIA container runtime opt out through the nvidia.com/gpu.deploy.container-toolkit=false label.
  EOT
  type        = bool
  default     = false
}

variable "gpu_operator_mig_strategy" {
  description = "MIG strategy exposed by the device plugin: none, single or mixed. Null keeps the chart default."
  type        = string
  default     = null

  validation {
    condition     = var.gpu_operator_mig_strategy == null || contains(["none", "single", "mixed"], coalesce(var.gpu_operator_mig_strategy, "none"))
    error_message = "gpu_operator_mig_strategy must be none, single or mixed."
  }
}

variable "gpu_operator_values" {
  description = "Extra Helm values (YAML documents) merged after the module's values for the GPU Operator."
  type        = list(string)
  default     = []
}

################################
# NVIDIA Dynamo platform
################################

variable "dynamo_enabled" {
  description = "Install the NVIDIA Dynamo platform (Dynamo operator and CRDs)."
  type        = bool
  default     = false
}

variable "dynamo_version" {
  description = "Version of the dynamo-platform Helm chart (matches a Dynamo release, e.g. 1.5.1)."
  type        = string
  default     = "1.5.1"
}

variable "dynamo_chart_repository" {
  description = "Base URL serving the dynamo-platform-<version>.tgz chart archives."
  type        = string
  default     = "https://helm.ngc.nvidia.com/nvidia/ai-dynamo/charts"
}

variable "dynamo_namespace" {
  description = "Namespace of the Dynamo platform release."
  type        = string
  default     = "dynamo-system"
}

variable "dynamo_install_grove" {
  description = "Install the bundled Grove operator, required for multinode and disaggregated deployments."
  type        = bool
  default     = false
}

variable "dynamo_install_kai_scheduler" {
  description = "Install the bundled KAI Scheduler for GPU-aware gang scheduling (recommended with Grove)."
  type        = bool
  default     = false
}

variable "dynamo_install_nats" {
  description = "Install the bundled NATS server (optional: the default request/event planes use TCP and ZMQ)."
  type        = bool
  default     = false
}

variable "dynamo_install_etcd" {
  description = "Install the bundled etcd."
  type        = bool
  default     = false
}

variable "dynamo_prometheus_endpoint" {
  description = "Prometheus URL used by the Dynamo planner (SLA mode) and autoscaling. Null leaves it unset."
  type        = string
  default     = null
}

variable "dynamo_values" {
  description = "Extra Helm values (YAML documents) merged after the module's values for the Dynamo platform."
  type        = list(string)
  default     = []
}

################################
# Common
################################

variable "timeout" {
  description = "Seconds Helm waits for each release to become ready."
  type        = number
  default     = 900
}
