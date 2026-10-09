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
  k8s_version = coalesce(each.value.k8s_version, var.k8s_version)

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
  k8s_version = coalesce(each.value.k8s_version, var.k8s_version)

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
  gpu_drivers_preset = each.value.gpu_drivers_preset

  node_labels = merge({ "workload-type" = "gpu" }, each.value.node_labels)
  taints      = concat(each.value.gpu_taint ? [local.gpu_taint] : [], each.value.taints)

  cloud_init_user_data = each.value.cloud_init != null ? each.value.cloud_init : local.default_cloud_init

  # GPU nodes are scheduled after the CPU pool so cluster add-ons
  # (CoreDNS, Cilium operator, GPU Operator) have somewhere to run first.
  depends_on = [module.cpu_node_group]
}
