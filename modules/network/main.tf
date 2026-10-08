locals {
  create_pool = var.create && length(var.private_pool_cidrs) > 0
}

resource "nebius_vpc_v1_pool" "private" {
  count = local.create_pool ? 1 : 0

  parent_id  = var.parent_id
  name       = "${var.name}-private-pool"
  labels     = var.labels
  version    = "IPV4"
  visibility = "PRIVATE"
  cidrs      = [for cidr in var.private_pool_cidrs : { cidr = cidr }]
}

resource "nebius_vpc_v1_network" "this" {
  count = var.create ? 1 : 0

  parent_id = var.parent_id
  name      = "${var.name}-network"
  labels    = var.labels

  # null => the network is attached to the project's default private pools.
  ipv4_private_pools = local.create_pool ? {
    pools = [{ id = nebius_vpc_v1_pool.private[0].id }]
  } : null
}

resource "nebius_vpc_v1_subnet" "this" {
  count = var.create ? 1 : 0

  parent_id  = var.parent_id
  name       = "${var.name}-subnet"
  labels     = var.labels
  network_id = nebius_vpc_v1_network.this[0].id

  ipv4_private_pools = length(var.subnet_cidrs) > 0 ? {
    use_network_pools = false
    pools = [{
      cidrs = [for cidr in var.subnet_cidrs : { cidr = cidr }]
    }]
  } : { use_network_pools = true }
}

data "nebius_vpc_v1_subnet" "existing" {
  count = var.create ? 0 : 1

  id = var.existing_subnet_id

  lifecycle {
    precondition {
      condition     = var.existing_subnet_id != null
      error_message = "existing_subnet_id must be set when create = false."
    }
  }
}
