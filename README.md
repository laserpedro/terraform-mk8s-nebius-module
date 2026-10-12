# terraform-mk8s-nebius-module

Terraform module that provisions a **Nebius AI Cloud Managed Service for Kubernetes (mk8s)** cluster
together with everything it needs:

| Layer | What gets created | Nebius resources |
|---|---|---|
| Networking | VPC network, optional dedicated private IPv4 pool, subnet — or reuse of an existing subnet | `nebius_vpc_v1_pool`, `nebius_vpc_v1_network`, `nebius_vpc_v1_subnet` |
| IAM | Node service account, a per-cluster group holding its project roles, optional membership in tenant groups, optional access groups for operators | `nebius_iam_v1_service_account`, `nebius_iam_v1_group`, `nebius_iam_v1_access_permit`, `nebius_iam_v1_group_membership` |
| Control plane | Managed Kubernetes cluster (public and/or private endpoint, 1 or 3 etcd members) | `nebius_mk8s_v1_cluster` |
| CPU node groups | Any number of CPU pools, fixed size or autoscaled | `nebius_mk8s_v1_node_group` |
| GPU node groups | Any number of GPU pools with NVIDIA drivers preinstalled (or driverless), optionally on an InfiniBand GPU cluster, GPU taint | `nebius_compute_v1_gpu_cluster`, `nebius_mk8s_v1_node_group` |
| GPU software stack | NVIDIA GPU Operator (on by default with GPU pools) and NVIDIA Dynamo platform (opt-in) | `helm_release` |

```
.
├── main.tf / variables.tf / outputs.tf / versions.tf   # root module: wires the layers together
├── templates/cloud-init.yaml.tftpl                     # SSH user provisioning for nodes
├── modules/
│   ├── network/      # VPC pool, network, subnet (or lookup of an existing subnet)
│   ├── iam/          # service account, groups, access permits, memberships
│   ├── node-group/   # one mk8s node group (used for both CPU and GPU pools)
│   └── addons/       # Helm releases: NVIDIA GPU Operator, NVIDIA Dynamo platform (+ unit tests)
└── examples/
    ├── complete/          # new network, IAM groups, autoscaled CPU pool, InfiniBand H100 pool, GPU Operator + Dynamo
    └── existing-network/  # existing subnet + service account, private API, single-GPU pool + GPU Operator
```

## Prerequisites

* Terraform >= 1.5
* The Nebius provider (`nebius/nebius`). See the
  [Nebius Terraform provider docs](https://docs.nebius.com/terraform-provider/quickstart) for installation —
  if your environment cannot reach the public registry, configure the Nebius mirror in `~/.terraformrc`.
* Credentials: the provider uses your Nebius CLI profile or an IAM token, e.g.
  `export NEBIUS_IAM_TOKEN=$(nebius iam get-access-token)`.
* The `hashicorp/helm` provider (2.12+ or 3.x), configured by you against the cluster, whenever the module
  installs the GPU software stack (any GPU node group, or `dynamo.enabled`). See [Usage](#usage).
* Enough quota in the project for the chosen CPU/GPU platforms.

## Usage

```hcl
provider "nebius" {
  domain = "api.eu.nebius.cloud:443"
}

# Used to install the GPU Operator and Dynamo into the new cluster.
# export TF_VAR_iam_token=$(nebius iam get-access-token)
provider "helm" {
  kubernetes = {
    host                   = module.mk8s.cluster_public_endpoint
    cluster_ca_certificate = module.mk8s.cluster_ca_certificate
    token                  = var.iam_token
  }
}

module "mk8s" {
  source = "github.com/laserpedro/terraform-mk8s-nebius-module"

  parent_id = "project-e00xxxxxxxxxxxxxxxx"
  name      = "ml-training"

  network = {
    private_pool_cidrs = ["10.20.0.0/16"]
    subnet_cidrs       = ["10.20.0.0/20"]
  }

  iam = {
    node_service_account_roles = ["editor"]
  }

  access_groups = {
    admins = { roles = ["editor"], member_ids = ["useraccount-e00xxxxxxxxxxxxxxxx"] }
  }

  k8s_version    = "1.35"
  ssh_public_key = file("~/.ssh/id_ed25519.pub")

  cpu_node_groups = {
    system = {
      preset      = "8vcpu-32gb"
      autoscaling = { min_node_count = 2, max_node_count = 4 }
    }
  }

  gpu_node_groups = {
    h100 = {
      platform           = "gpu-h100-sxm"
      preset             = "8gpu-128vcpu-1600gb"
      fixed_node_count   = 2
      infiniband_fabric  = "fabric-3"
    }
  }

  dynamo = {
    enabled               = true
    install_grove         = true
    install_kai_scheduler = true
  }
}
```

Then fetch a kubeconfig and check the GPU stack:

```sh
$(terraform output -raw get_credentials_command)
kubectl get nodes -L workload-type,nvidia.com/gpu.product
kubectl get pods -n gpu-operator             # device plugin, GFD, DCGM, validator
kubectl get crd | grep dynamo                # dynamographdeployments, dynamographdeploymentrequests, ...
kubectl get pods -n dynamo-system            # dynamo-operator
```

## Design notes

### Networking
* `network.create = true` (default) creates a network and a subnet. With `private_pool_cidrs` the
  network gets its own private pool; otherwise it uses the project's default pools.
  `subnet_cidrs` carves explicit ranges out of the network pools; otherwise the subnet uses the whole pool.
* `network.create = false` plugs the cluster into `existing_subnet_id` and only reads it.
* The control plane and all node groups share the same subnet.

### IAM
* By default a service account `<name>-nodes-sa` is created and every node group runs as it.
* Its roles (`iam.node_service_account_roles`, default `["editor"]`, needed e.g. to pull from Nebius Container
  Registry and attach volumes) are granted to a per-cluster group `<name>-nodes` with
  `nebius_iam_v1_access_permit` on the project, rather than via the tenant-wide `editors` group. Narrow the
  list to fit your security posture. If you prefer the tenant group, set
  `iam.node_service_account_tenant_groups = ["editors"]` and `tenant_id`.
* Node groups depend on the IAM memberships, so nodes never boot with a service account that lacks permissions.
* `access_groups` creates groups named `<name>-<key>`, grants each the listed roles on the project and adds
  the listed user/service accounts.

### Node groups
* `cpu_node_groups` and `gpu_node_groups` are maps; each entry becomes a node group named `<name>-<key>`.
  At least one CPU group is required so system add-ons have somewhere to run; GPU groups are created after it.
* Sizing: set `autoscaling = { min_node_count, max_node_count }` for the cluster autoscaler, otherwise
  `fixed_node_count` is used.
* GPU groups:
  * `infiniband_fabric` creates a dedicated `nebius_compute_v1_gpu_cluster` for that group
    (8-GPU presets only); `gpu_cluster_id` places it in an existing one.
  * NVIDIA drivers come preinstalled: GPU nodes boot a Nebius driver-full image (`gpu_drivers_preset`,
    default `cuda13.0`, requires Kubernetes 1.35+). Set `preinstalled_drivers = false` for a driverless image
    whose driver is installed by the GPU Operator instead.
  * `gpu_taint = true` (default) adds `nvidia.com/gpu=true:NoSchedule`; GPU workloads need a matching toleration.
  * `reservation_ids` pins the nodes to capacity reservations.
* Every node gets a `workload-type=cpu|gpu` Kubernetes label in addition to `node_labels`.
* `ssh_public_key` provisions `ssh_user_name` on every node via cloud-init; a per-group `cloud_init` overrides it.

### GPU software stack

Installed by `modules/addons` with Helm after the CPU node groups are up, so the operators have somewhere to run.

* **NVIDIA drivers.** GPU nodes boot Nebius driver-full images (`gpu_drivers_preset = "cuda13.0"`), so the
  driver is on the node from the start. Pools with `preinstalled_drivers = false` boot driverless images, and the
  GPU Operator installs the driver on them instead.
* **NVIDIA GPU Operator** (`gpu_operator`, chart `v26.7.1`, namespace `gpu-operator`), installed whenever at
  least one GPU node group exists. It provides the device plugin (`nvidia.com/gpu` resources), GPU feature
  discovery, DCGM/DCGM exporter and the validator.
  * Driver-full pools get the node labels `nvidia.com/gpu.deploy.driver=false` and
    `nvidia.com/gpu.deploy.container-toolkit=false`. The operator keeps labels that are already set, so it
    leaves the preinstalled driver and container runtime alone.
  * The operator's driver and toolkit DaemonSets are only enabled when some pool is driverless, so driver-full
    and driverless pools can share a cluster.
  * If your driver-full image does not configure the NVIDIA container runtime, set
    `gpu_operator.preinstalled_toolkit = false` and the operator manages the toolkit.
  * A plan fails if a pool is driverless while `gpu_operator.enabled = false`.
* **NVIDIA Dynamo platform** (`dynamo`, chart `dynamo-platform` `1.5.1` from NGC, namespace `dynamo-system`):
  opt-in with `dynamo.enabled = true`. It installs the Dynamo operator and CRDs (`DynamoGraphDeployment`,
  `DynamoGraphDeploymentRequest`, ...). For multinode or disaggregated serving set `install_grove` and
  `install_kai_scheduler`. NATS/etcd are optional in current releases, and `prometheus_endpoint` enables the
  planner's SLA mode.
* Pin other chart versions with `gpu_operator.version` / `dynamo.version`. Pass any other Helm values as YAML
  through `gpu_operator.values` / `dynamo.values`, e.g. `values = [file("gpu-operator-values.yaml")]`.
* Not installed by this module: the NVIDIA Network Operator (RDMA for InfiniBand) and kube-prometheus-stack.
  Dynamo works without them, but disaggregated KV-cache transfer falls back to TCP without RDMA.

## Inputs

| Name | Description | Type | Default |
|---|---|---|---|
| `parent_id` | Project ID (`project-...`) | `string` | required |
| `name` | Cluster name and resource prefix | `string` | required |
| `tenant_id` | Tenant ID, only for tenant group lookups | `string` | `null` |
| `labels` | Nebius labels on all resources | `map(string)` | `{}` |
| `network` | Networking layer settings (see above) | `object` | `{}` (create everything) |
| `iam` | Node service account settings | `object` | `{}` (create SA with `editor`) |
| `access_groups` | Operator access groups | `map(object)` | `{}` |
| `k8s_version` | Kubernetes `major.minor` (1.35+ for `cuda13.0` driver images) | `string` | `null` (Nebius default) |
| `public_endpoint` | Public Kubernetes API endpoint | `bool` | `true` |
| `etcd_cluster_size` | `1` or `3` | `number` | `3` |
| `service_cidrs` | Kubernetes Service CIDRs | `list(string)` | `null` (Nebius default) |
| `ssh_user_name` | Node SSH user | `string` | `"ubuntu"` |
| `ssh_public_key` | Node SSH public key | `string` | `null` |
| `cpu_node_groups` | CPU node groups | `map(object)` | `{ system = {} }` (2 × `cpu-d3` `16vcpu-64gb`) |
| `gpu_node_groups` | GPU node groups | `map(object)` | `{}` |
| `gpu_operator` | NVIDIA GPU Operator settings (`enabled`, `version`, `namespace`, `mig_strategy`, `preinstalled_toolkit`, `values`) | `object` | `{}` (enabled, `v26.7.1`) |
| `dynamo` | NVIDIA Dynamo platform settings (`enabled`, `version`, `namespace`, `install_grove`, `install_kai_scheduler`, `install_nats`, `install_etcd`, `prometheus_endpoint`, `values`) | `object` | `{}` (disabled, `1.5.1`) |
| `addons_timeout` | Seconds Helm waits for each add-on release | `number` | `900` |

Every field of the `cpu_node_groups` / `gpu_node_groups` objects is optional and documented in
[`variables.tf`](variables.tf).

## Outputs

| Name | Description |
|---|---|
| `cluster_id`, `cluster_name` | Cluster identity |
| `cluster_public_endpoint`, `cluster_private_endpoint`, `cluster_ca_certificate` | API access details (e.g. for the `kubernetes`/`helm` providers) |
| `get_credentials_command` | `nebius mk8s cluster get-credentials ...` command |
| `network_id`, `subnet_id` | Networking layer |
| `node_service_account_id`, `access_group_ids` | IAM layer |
| `cpu_node_group_ids`, `gpu_node_group_ids`, `gpu_cluster_ids` | Node groups |
| `gpu_operator_namespace`, `dynamo_namespace` | GPU software stack (null when not installed) |

## Testing

`modules/addons` has unit tests that run against a mocked helm provider (no cluster needed):

```sh
terraform -chdir=modules/addons init
terraform -chdir=modules/addons test
```

## Platform/preset reference

Availability differs per region; check the Nebius console or `nebius compute platform list`.

| Platform | Example presets |
|---|---|
| `cpu-d3` | `4vcpu-16gb`, `8vcpu-32gb`, `16vcpu-64gb`, ... |
| `cpu-e2` | `4vcpu-16gb`, `8vcpu-32gb`, ... |
| `gpu-h100-sxm` | `1gpu-16vcpu-200gb`, `8gpu-128vcpu-1600gb` |
| `gpu-h200-sxm` | `1gpu-16vcpu-200gb`, `8gpu-128vcpu-1600gb` |
| `gpu-b200-sxm` | `8gpu-160vcpu-1792gb` |
| `gpu-l40s-a` | `1gpu-8vcpu-32gb`, ... |
