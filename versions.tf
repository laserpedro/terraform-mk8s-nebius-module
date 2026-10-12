terraform {
  required_version = ">= 1.5.0"

  required_providers {
    nebius = {
      source  = "nebius/nebius"
      version = ">= 0.5.55"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12.0, < 4.0.0"
    }
  }
}
