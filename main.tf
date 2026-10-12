locals {
  labels = merge({ "managed-by" = "terraform", "mk8s-cluster" = var.name }, var.labels)

  default_cloud_init = var.ssh_public_key == null ? null : templatefile(
    "${path.module}/templates/cloud-init.yaml.tftpl",
    {
      ssh_user_name  = var.ssh_user_name
      ssh_public_key = trimspace(var.ssh_public_key)
    }
  )

  gpu_taint = { key = "nvidia.com/gpu", value = "true", effect = "NO_SCHEDULE" }

  # GPU software stack: the operator only installs drivers/toolkit where the node image lacks them.
  gpu_operator_enabled = var.gpu_operator.enabled && length(var.gpu_node_groups) > 0
  any_driverless_gpu   = anytrue([for ng in values(var.gpu_node_groups) : !ng.preinstalled_drivers])

  # Driver-full nodes opt out of the operator's driver (and toolkit) DaemonSets. The operator
  # only sets nvidia.com/gpu.deploy.* labels that are missing, so these values are kept.
  preinstalled_driver_labels = merge(
    { "nvidia.com/gpu.deploy.driver" = "false" },
    var.gpu_operator.preinstalled_toolkit ? { "nvidia.com/gpu.deploy.container-toolkit" = "false" } : {},
  )

  # GPU groups that need a new InfiniBand GPU cluster created for them.
  gpu_fabric_groups = {
    for k, ng in var.gpu_node_groups : k => ng.infiniband_fabric if ng.infiniband_fabric != null
  }
}

################################
# Networking layer
################################

module "network" {
  source = "./modules/network"

  parent_id          = var.parent_id
  name               = var.name
  labels             = local.labels
  create             = var.network.create
  existing_subnet_id = var.network.existing_subnet_id
  private_pool_cidrs = var.network.private_pool_cidrs
  subnet_cidrs       = var.network.subnet_cidrs
}

################################
# IAM layer
################################

module "iam" {
  source = "./modules/iam"

  parent_id                          = var.parent_id
  tenant_id                          = var.tenant_id
  name                               = var.name
  create_node_service_account        = var.iam.create_node_service_account
  existing_node_service_account_id   = var.iam.existing_node_service_account_id
  node_service_account_roles         = var.iam.node_service_account_roles
  node_service_account_tenant_groups = var.iam.node_service_account_tenant_groups
  access_groups                      = var.access_groups
}

################################
# Control plane
################################

resource "nebius_mk8s_v1_cluster" "this" {
  parent_id = var.parent_id
  name      = var.name
  labels    = local.labels

  control_plane = {
    version           = var.k8s_version
    subnet_id         = module.network.subnet_id
    etcd_cluster_size = var.etcd_cluster_size
    endpoints = {
      public_endpoint = var.public_endpoint ? {} : null
    }
  }

  kube_network = var.service_cidrs == null ? null : {
    service_cidrs = var.service_cidrs
  }

  lifecycle {
    precondition {
      condition     = !local.any_driverless_gpu || local.gpu_operator_enabled
      error_message = "GPU node groups with preinstalled_drivers = false need gpu_operator.enabled = true to install the NVIDIA driver."
    }
  }
}

################################
# CPU node groups
################################

module "cpu_node_group" {
  source   = "./modules/node-group"
  for_each = var.cpu_node_groups

  cluster_id  = nebius_mk8s_v1_cluster.this.id
  name        = "${var.name}-${each.key}"
  labels      = local.labels
  k8s_version = each.value.k8s_version != null ? each.value.k8s_version : var.k8s_version

  fixed_node_count = each.value.fixed_node_count
  autoscaling      = each.value.autoscaling
  strategy         = each.value.strategy

  platform           = each.value.platform
  preset             = each.value.preset
  boot_disk_type     = each.value.boot_disk_type
  boot_disk_size_gib = each.value.boot_disk_size_gib
  os                 = each.value.os
  preemptible        = each.value.preemptible

  subnet_id          = module.network.subnet_id
  public_ip          = each.value.public_ip
  service_account_id = module.iam.node_service_account_id

  node_labels = merge({ "workload-type" = "cpu" }, each.value.node_labels)
  taints      = each.value.taints

  cloud_init_user_data = each.value.cloud_init != null ? each.value.cloud_init : local.default_cloud_init
}

################################
# GPU node groups
################################

resource "nebius_compute_v1_gpu_cluster" "this" {
  for_each = local.gpu_fabric_groups

  parent_id         = var.parent_id
  name              = "${var.name}-${each.key}-${each.value}"
  labels            = local.labels
  infiniband_fabric = each.value
}

module "gpu_node_group" {
  source   = "./modules/node-group"
  for_each = var.gpu_node_groups

  cluster_id  = nebius_mk8s_v1_cluster.this.id
  name        = "${var.name}-${each.key}"
  labels      = local.labels
  k8s_version = each.value.k8s_version != null ? each.value.k8s_version : var.k8s_version

  fixed_node_count = each.value.fixed_node_count
  autoscaling      = each.value.autoscaling
  strategy         = each.value.strategy

  platform           = each.value.platform
  preset             = each.value.preset
  boot_disk_type     = each.value.boot_disk_type
  boot_disk_size_gib = each.value.boot_disk_size_gib
  os                 = each.value.os
  preemptible        = each.value.preemptible
  reservation_ids    = each.value.reservation_ids

  subnet_id          = module.network.subnet_id
  public_ip          = each.value.public_ip
  service_account_id = module.iam.node_service_account_id

  # Created GPU cluster for groups with infiniband_fabric, otherwise the existing one (or none).
  gpu_cluster_id = lookup(
    { for k, c in nebius_compute_v1_gpu_cluster.this : k => c.id },
    each.key,
    each.value.gpu_cluster_id,
  )
  gpu_drivers_preset = each.value.preinstalled_drivers ? each.value.gpu_drivers_preset : null

  node_labels = merge(
    { "workload-type" = "gpu" },
    local.gpu_operator_enabled && each.value.preinstalled_drivers ? local.preinstalled_driver_labels : {},
    each.value.node_labels,
  )
  taints = concat(each.value.gpu_taint ? [local.gpu_taint] : [], each.value.taints)

  cloud_init_user_data = each.value.cloud_init != null ? each.value.cloud_init : local.default_cloud_init

  # GPU nodes are scheduled after the CPU pool so cluster add-ons
  # (CoreDNS, Cilium operator, GPU Operator) have somewhere to run first.
  depends_on = [module.cpu_node_group]
}

################################
# GPU software stack
################################

module "addons" {
  source = "./modules/addons"
  count  = local.gpu_operator_enabled || var.dynamo.enabled ? 1 : 0

  gpu_operator_enabled         = local.gpu_operator_enabled
  gpu_operator_version         = var.gpu_operator.version
  gpu_operator_namespace       = var.gpu_operator.namespace
  gpu_operator_install_driver  = local.any_driverless_gpu
  gpu_operator_install_toolkit = local.any_driverless_gpu || !var.gpu_operator.preinstalled_toolkit
  gpu_operator_mig_strategy    = var.gpu_operator.mig_strategy
  gpu_operator_values          = var.gpu_operator.values

  dynamo_enabled               = var.dynamo.enabled
  dynamo_version               = var.dynamo.version
  dynamo_namespace             = var.dynamo.namespace
  dynamo_install_grove         = var.dynamo.install_grove
  dynamo_install_kai_scheduler = var.dynamo.install_kai_scheduler
  dynamo_install_nats          = var.dynamo.install_nats
  dynamo_install_etcd          = var.dynamo.install_etcd
  dynamo_prometheus_endpoint   = var.dynamo.prometheus_endpoint
  dynamo_values                = var.dynamo.values

  timeout = var.addons_timeout

  # Operators run on the CPU pool; GPU nodes join whenever they are ready.
  depends_on = [module.cpu_node_group]
}
