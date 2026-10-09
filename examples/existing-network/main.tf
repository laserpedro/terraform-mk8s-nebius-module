terraform {
  required_version = ">= 1.5.0"

  required_providers {
    nebius = {
      source  = "nebius/nebius"
      version = ">= 0.5.55"
    }
  }
}

provider "nebius" {
  domain = "api.eu.nebius.cloud:443"
}

# Minimal cluster in an existing subnet, reusing an existing service account,
# with a single autoscaled CPU pool and a autoscaled single-GPU pool.
module "mk8s" {
  source = "../.."

  parent_id = var.parent_id
  name      = "inference"

  network = {
    create             = false
    existing_subnet_id = var.subnet_id
  }

  iam = {
    create_node_service_account      = false
    existing_node_service_account_id = var.node_service_account_id
  }

  public_endpoint   = false
  etcd_cluster_size = 1

  cpu_node_groups = {
    system = {
      preset           = "4vcpu-16gb"
      fixed_node_count = 2
    }
  }

  gpu_node_groups = {
    l40s = {
      platform    = "gpu-l40s-a"
      preset      = "1gpu-8vcpu-32gb"
      autoscaling = { min_node_count = 1, max_node_count = 4 }
      preemptible = true
    }
  }
}

variable "parent_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "node_service_account_id" {
  type = string
}

output "cluster_id" {
  value = module.mk8s.cluster_id
}
