################################
# NVIDIA GPU Operator
################################

locals {
  gpu_operator_values = {
    driver = {
      enabled = var.gpu_operator_install_driver
    }
    toolkit = {
      enabled = var.gpu_operator_install_toolkit
    }
    mig = var.gpu_operator_mig_strategy == null ? null : {
      strategy = var.gpu_operator_mig_strategy
    }
  }
}

resource "helm_release" "gpu_operator" {
  count = var.gpu_operator_enabled ? 1 : 0

  name             = "gpu-operator"
  repository       = "https://helm.ngc.nvidia.com/nvidia"
  chart            = "gpu-operator"
  version          = var.gpu_operator_version
  namespace        = var.gpu_operator_namespace
  create_namespace = true

  wait    = true
  atomic  = true
  timeout = var.timeout

  values = concat(
    [yamlencode({ for k, v in local.gpu_operator_values : k => v if v != null })],
    var.gpu_operator_values,
  )
}

################################
# NVIDIA Dynamo platform
################################

locals {
  dynamo_values = {
    global = {
      grove           = { install = var.dynamo_install_grove }
      "kai-scheduler" = { install = var.dynamo_install_kai_scheduler }
      nats            = { install = var.dynamo_install_nats }
      etcd            = { install = var.dynamo_install_etcd }
    }
  }

  # Recommended by the Dynamo install guide when KAI Scheduler is bundled.
  dynamo_kai_values = {
    "kai-scheduler" = {
      scheduler = {
        args = { "default-staleness-grace-period" = "-1s" }
      }
    }
  }

  dynamo_prometheus_values = {
    "dynamo-operator" = {
      dynamo = {
        metrics = { prometheusEndpoint = var.dynamo_prometheus_endpoint }
      }
    }
  }
}

resource "helm_release" "dynamo_platform" {
  count = var.dynamo_enabled ? 1 : 0

  name             = "dynamo-platform"
  chart            = "${var.dynamo_chart_repository}/dynamo-platform-${var.dynamo_version}.tgz"
  namespace        = var.dynamo_namespace
  create_namespace = true

  wait    = true
  atomic  = true
  timeout = var.timeout

  values = concat(
    [yamlencode(local.dynamo_values)],
    var.dynamo_install_kai_scheduler ? [yamlencode(local.dynamo_kai_values)] : [],
    var.dynamo_prometheus_endpoint != null ? [yamlencode(local.dynamo_prometheus_values)] : [],
    var.dynamo_values,
  )

  # Dynamo workers request nvidia.com/gpu, which only exists once the GPU Operator's device plugin runs.
  depends_on = [helm_release.gpu_operator]
}
