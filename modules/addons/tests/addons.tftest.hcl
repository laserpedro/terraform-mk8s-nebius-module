# Unit tests for the add-ons module. The helm provider is mocked, so no cluster is needed:
#   terraform -chdir=modules/addons init && terraform -chdir=modules/addons test

mock_provider "helm" {}

run "defaults_install_gpu_operator_only" {
  command = plan

  assert {
    condition     = length(helm_release.gpu_operator) == 1 && length(helm_release.dynamo_platform) == 0
    error_message = "Defaults must install the GPU Operator and not Dynamo."
  }

  assert {
    condition     = helm_release.gpu_operator[0].version == "v26.7.1" && helm_release.gpu_operator[0].namespace == "gpu-operator"
    error_message = "Unexpected GPU Operator chart version or namespace."
  }

  assert {
    condition     = yamldecode(helm_release.gpu_operator[0].values[0]) == { driver = { enabled = false }, toolkit = { enabled = false } }
    error_message = "Driver-full defaults must disable the operator's driver and toolkit and omit unset MIG settings."
  }
}

run "driverless_nodes_enable_driver_and_toolkit" {
  command = plan

  variables {
    gpu_operator_install_driver  = true
    gpu_operator_install_toolkit = true
    gpu_operator_mig_strategy    = "single"
    gpu_operator_values          = ["dcgmExporter:\n  enabled: false\n"]
  }

  assert {
    condition = yamldecode(helm_release.gpu_operator[0].values[0]) == {
      driver  = { enabled = true }
      toolkit = { enabled = true }
      mig     = { strategy = "single" }
    }
    error_message = "Driver, toolkit and MIG settings were not rendered."
  }

  assert {
    condition     = helm_release.gpu_operator[0].values[1] == "dcgmExporter:\n  enabled: false\n"
    error_message = "Extra values must be applied after the module's values."
  }
}

run "dynamo_with_grove_and_kai" {
  command = plan

  variables {
    dynamo_enabled               = true
    dynamo_install_grove         = true
    dynamo_install_kai_scheduler = true
    dynamo_prometheus_endpoint   = "http://prometheus.monitoring:9090"
  }

  assert {
    condition     = helm_release.dynamo_platform[0].chart == "https://helm.ngc.nvidia.com/nvidia/ai-dynamo/charts/dynamo-platform-1.5.1.tgz"
    error_message = "Unexpected Dynamo chart URL."
  }

  assert {
    condition     = yamldecode(helm_release.dynamo_platform[0].values[0]).global.grove.install && yamldecode(helm_release.dynamo_platform[0].values[0]).global["kai-scheduler"].install
    error_message = "Grove and KAI Scheduler must be bundled when requested."
  }

  assert {
    condition     = yamldecode(helm_release.dynamo_platform[0].values[1])["kai-scheduler"].scheduler.args["default-staleness-grace-period"] == "-1s"
    error_message = "KAI Scheduler staleness grace period override is missing."
  }

  assert {
    condition     = yamldecode(helm_release.dynamo_platform[0].values[2])["dynamo-operator"].dynamo.metrics.prometheusEndpoint == "http://prometheus.monitoring:9090"
    error_message = "Prometheus endpoint was not passed to the Dynamo operator."
  }
}

run "dynamo_only" {
  command = plan

  variables {
    gpu_operator_enabled = false
    dynamo_enabled       = true
  }

  assert {
    condition     = length(helm_release.gpu_operator) == 0 && length(helm_release.dynamo_platform[0].values) == 1
    error_message = "Dynamo alone must render only the base values document."
  }
}

run "rejects_invalid_mig_strategy" {
  command = plan

  variables {
    gpu_operator_mig_strategy = "all"
  }

  expect_failures = [var.gpu_operator_mig_strategy]
}
