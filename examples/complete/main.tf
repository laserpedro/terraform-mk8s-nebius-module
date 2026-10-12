terraform {
  required_version = ">= 1.5.0"

  required_providers {
    nebius = {
      source  = "nebius/nebius"
      version = ">= 0.5.55"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }
}

# Authenticates with the Nebius CLI profile / IAM token from the environment
# (e.g. `export NEBIUS_IAM_TOKEN=$(nebius iam get-access-token)`).
provider "nebius" {
  domain = "api.eu.nebius.cloud:443"
}

# Installs the GPU Operator and Dynamo into the new cluster through its public endpoint.
# export TF_VAR_iam_token=$(nebius iam get-access-token)
provider "helm" {
  kubernetes = {
    host                   = module.mk8s.cluster_public_endpoint
    cluster_ca_certificate = module.mk8s.cluster_ca_certificate
    token                  = var.iam_token
  }
}

module "mk8s" {
  source = "../.."

  parent_id = var.parent_id
  tenant_id = var.tenant_id
  name      = var.cluster_name

  labels = {
    environment = "dev"
    team        = "ml-platform"
  }

  # Networking layer: dedicated private pool and a /20 subnet for the cluster.
  network = {
    private_pool_cidrs = ["10.20.0.0/16"]
    subnet_cidrs       = ["10.20.0.0/20"]
  }

  # IAM layer: nodes run as a dedicated service account with project editor rights,
  # and two groups are created for people who operate the cluster.
  iam = {
    node_service_account_roles = ["editor"]
  }
  access_groups = {
    admins  = { roles = ["editor"], member_ids = var.admin_member_ids }
    viewers = { roles = ["viewer"], member_ids = var.viewer_member_ids }
  }

  # Control plane.
  k8s_version       = "1.35"
  public_endpoint   = true
  etcd_cluster_size = 3

  ssh_public_key = var.ssh_public_key

  # CPU pool for system add-ons and general workloads.
  cpu_node_groups = {
    system = {
      platform    = "cpu-d3"
      preset      = "8vcpu-32gb"
      autoscaling = { min_node_count = 2, max_node_count = 4 }
    }
  }

  # GPU pool on an InfiniBand fabric. Nodes boot with NVIDIA drivers preinstalled (cuda13.0).
  gpu_node_groups = {
    h100 = {
      platform           = "gpu-h100-sxm"
      preset             = "8gpu-128vcpu-1600gb"
      fixed_node_count   = 2
      infiniband_fabric  = var.infiniband_fabric
      boot_disk_size_gib = 1024
    }
  }

  # GPU software stack: the GPU Operator (on by default with GPU node groups) and the
  # Dynamo platform with Grove + KAI Scheduler for multinode / disaggregated serving.
  dynamo = {
    enabled               = true
    install_grove         = true
    install_kai_scheduler = true
  }
}
