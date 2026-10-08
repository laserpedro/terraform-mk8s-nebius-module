resource "nebius_mk8s_v1_node_group" "this" {
  parent_id = var.cluster_id
  name      = var.name
  labels    = var.labels
  version   = var.k8s_version

  fixed_node_count = var.autoscaling == null ? var.fixed_node_count : null
  autoscaling = var.autoscaling == null ? null : {
    min_node_count = var.autoscaling.min_node_count
    max_node_count = var.autoscaling.max_node_count
  }

  strategy = var.strategy

  template = {
    metadata = {
      labels = var.node_labels
    }
    taints = length(var.taints) > 0 ? var.taints : null

    resources = {
      platform = var.platform
      preset   = var.preset
    }

    boot_disk = {
      type           = var.boot_disk_type
      size_gibibytes = var.boot_disk_size_gib
    }

    os = var.os

    network_interfaces = [{
      subnet_id         = var.subnet_id
      public_ip_address = var.public_ip ? {} : null
    }]

    service_account_id = var.service_account_id

    gpu_cluster  = var.gpu_cluster_id != null ? { id = var.gpu_cluster_id } : null
    gpu_settings = var.gpu_drivers_preset != null ? { drivers_preset = var.gpu_drivers_preset } : null

    preemptible = var.preemptible ? {
      on_preemption = "STOP"
      priority      = 3
    } : null

    reservation_policy = length(var.reservation_ids) > 0 ? {
      policy          = "STRICT"
      reservation_ids = var.reservation_ids
    } : null

    cloud_init_user_data = var.cloud_init_user_data
  }

  lifecycle {
    precondition {
      condition = var.autoscaling == null || try(
        var.autoscaling.min_node_count <= var.autoscaling.max_node_count, false
      )
      error_message = "Node group ${var.name}: autoscaling.min_node_count must be <= max_node_count."
    }
  }
}
