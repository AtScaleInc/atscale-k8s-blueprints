# AtScale K8S Blueprint - Azure (AKS)

This blueprint creates an AKS (Azure Kubernetes Service) cluster on Azure with networking, storage, and optional database resources.

## What Gets Created

- Virtual Network (VNet) with subnets for AKS and optional PostgreSQL
- AKS cluster with RBAC and Azure AD integration (nodes always in private subnets)
- Log Analytics workspace
- Network Security Groups
- Gateway API and Application Gateway for Containers add-ons, so the cluster can serve ingress out of the box (see [Ingress gateway](#ingress-gateway))
- `azurefile-csi-nfs` StorageClass for ReadWriteMany (RWX) volumes (see [Storage](#storage))
- Optional: Azure PostgreSQL Flexible Server with private networking

## Prerequisites

1. **Azure CLI** - [Install](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
2. **kubelogin** - [Install](https://github.com/Azure/kubelogin)
3. **Terraform >= 1.11.0** - [Install](https://www.terraform.io/downloads)
4. **Make** - Pre-installed on macOS/Linux
5. **kubectl** - [Install](https://kubernetes.io/docs/tasks/tools/)

6. **Azure permissions** - see [Required permissions](#required-permissions)

7. **Preview features for the ingress gateway add-ons** (only with `minimal_cluster = false` and `enable_ingress_gateway = true`; not needed for the default minimal cluster):

```sh
az feature register --namespace Microsoft.ContainerService --name ManagedGatewayAPIPreview
az feature register --namespace Microsoft.ContainerService --name ApplicationLoadBalancerPreview
az provider register --namespace Microsoft.NetworkFunction
az provider register --namespace Microsoft.ServiceNetworking

# Registration is asynchronous. Wait until both report "Registered":
az feature show --namespace Microsoft.ContainerService --name ManagedGatewayAPIPreview --query properties.state -o tsv
az feature show --namespace Microsoft.ContainerService --name ApplicationLoadBalancerPreview --query properties.state -o tsv

# Then propagate the feature registrations:
az provider register --namespace Microsoft.ContainerService
```

Verify prerequisites:
```sh
bash ../../scripts/check-prerequisites.sh azure
```

The prerequisites script checks these registrations and fails with the exact
commands to run if any are missing.

### Required permissions

The identity that runs `make create-cluster` (a user or a service principal) needs, on the
subscription or on the target resource groups:

| Role | Why |
|------|-----|
| **Contributor** | Creates the resource groups, VNet, Log Analytics, AKS, PostgreSQL and the Terraform state storage account, and registers resource providers |
| **Role Based Access Control Administrator** | Creates the role assignments: `Network Contributor` for the cluster and ALB identities on their subnets, and `Azure Kubernetes Service RBAC Cluster Admin` for the deployer |

`Owner` covers both, but grants more than is needed. To keep it least-privilege, add a
condition to the Role Based Access Control Administrator assignment that allows only the
`Network Contributor` and `Azure Kubernetes Service RBAC Cluster Admin` roles.

Terraform makes the deployer a Kubernetes cluster-admin (`grant_deployer_cluster_admin = true`),
which is what the post-create steps and the AtScale Helm install need (they create namespaces,
CRDs, ClusterRoles and StorageClasses). An Entra ID admin group (`aad_admin_group_object_id`)
is optional; set it to give other people admin access too.

## Quick Start

```sh
cd environments/azure
make create-cluster
```

The Makefile guides you through the full deployment in two phases:

**Phase 1 — Configuration (nothing is created yet):**
1. Prompts for Terraform backend settings (Azure Storage Account for state)
2. Prompts for cluster settings (environment, region, resource group, minimal cluster, VNet CIDR, K8s version, VM size, pod and service CIDRs, API access, ingress gateway, PostgreSQL)
3. Displays a full deployment summary
4. Asks: `Proceed with deployment? (yes/no)` — only on "yes" does anything happen

**Phase 2 — Deployment:**
1. Creates the Azure Storage backend and generates `terraform.tfvars`
2. Runs `terraform plan` scoped to networking, asks for confirmation, applies VNet
3. Runs `terraform plan` for the full cluster, asks for confirmation, applies everything
4. Prints cluster access instructions

## Configuration

All configuration is managed through `terraform.tfvars`. The Makefile generates this file interactively on first run. You can also create or edit it manually.

**Required variables** (no defaults, prompted by Makefile):

| Variable | Description | Example |
|----------|-------------|---------|
| `environment` | Environment name | `"dev"` |
| `region` | Azure region | `"eastus"` |
| `vpc_cidr` | VNet address space (see [VNet sizing](#vnet-sizing)) | `"10.85.0.0/22"` |
| `resource_group_name` | Azure resource group | `"rg-atscale-dev"` |

**Optional variables** (have sensible defaults):

| Variable | Default | Description |
|----------|---------|-------------|
| `aks_version` | `"1.35"` | AKS Kubernetes version |
| `aad_admin_group_object_id` | `""` | Entra ID group whose members become cluster admins, in addition to the deployer |
| `grant_deployer_cluster_admin` | `true` | Give the identity running Terraform the `Azure Kubernetes Service RBAC Cluster Admin` role on the cluster |
| `minimal_cluster` | `true` | Deploy 1 node with no ingress gateway add-ons for dev/test and POCs. Overrides `aks_node_count`, `enable_ingress_gateway` and `create_default_alb`. Requires at least `Standard_D16s_v5` — see [Minimal cluster](#minimal-cluster) |
| `aks_node_count` | `3` | Number of worker nodes |
| `aks_node_size` | `"Standard_D8s_v5"` | VM size for nodes |
| `pod_cidr` | `"10.244.0.0/16"` | Azure CNI Overlay pod range (no VNet addresses; a fixed `/24` per node) |
| `service_cidr` | `"10.0.0.0/16"` | Kubernetes service range (smaller than `/12`) |
| `dns_service_ip` | 10th address of `service_cidr` | Cluster DNS service IP |
| `outbound_type` | `"loadBalancer"` | Cluster egress: `loadBalancer` or `userDefinedRouting` (see [Egress](#egress)) |
| `route_table_id` | `null` | Existing route table to associate with the node subnet; required for `userDefinedRouting` |
| `public_api_server` | `true` | Make the AKS API server publicly accessible |
| `authorized_network_cidr` | `""` | CIDR allowed to reach the API server when `public_api_server = false` |
| `enable_ingress_gateway` | `true` | Enable the Gateway API and Application Gateway for Containers add-ons (**preview** - see below) |
| `enable_postgresql` | `false` | Create PostgreSQL Flexible Server |
| `postgresql_version` | `"16"` | PostgreSQL version |
| `postgresql_sku_name` | `"GP_Standard_D4ads_v5"` | PostgreSQL SKU |
| `postgresql_storage_mb` | `65536` | PostgreSQL storage (MB) |
| `postgresql_backup_retention_days` | `7` | Backup retention days |
| `postgresql_admin_username` | `"postgres"` | Database admin username |

See `variables.tf` for the complete list of options.

### VNet sizing

The VNet is split into four equal subnets: PostgreSQL, AKS nodes, the Application Gateway for Containers association subnet, and one spare. Pods and services use the overlay ranges below, not VNet addresses, so the VNet only holds nodes, internal load balancer front ends and the private API server endpoint.

| Setup | Minimum `vpc_cidr` | Node subnet |
|---|---|---|
| `minimal_cluster = true` (or `enable_ingress_gateway = false`) | `/26` | `/28` (11 usable after Azure's 5 reserved addresses) |
| Production without the ingress gateway | `/25` | `/27` |
| `enable_ingress_gateway = true` | `/22` | `/24` (the gateway subnet must be at least a `/24`) |

`vpc_cidr` must be a network address (host bits zero). Terraform rejects invalid sizes at plan time.

### Minimal cluster

`minimal_cluster = true` deploys a single node and turns off the ingress gateway add-ons, so no preview features need registering and a `/26` VNet is enough. Expose AtScale through an internal Azure Load Balancer instead (the `service.beta.kubernetes.io/azure-load-balancer-internal: "true"` annotation on the AtScale proxy Service).

- **Node size:** all AtScale components run on one node, so use at least `Standard_D16s_v5` (16 vCPU / 64 GB RAM). Smaller sizes will likely leave pods stuck in `Pending`. If your subscription has no DSv5 quota in the region, `Standard_D16s_v6` is the same shape; `make create-cluster` checks the vCPU quota for the size you pick and asks again if it is short.
- **Availability zones:** unlike EKS, AKS needs no minimum number of zones. The node pool is regional (no zones set), which every region supports.
- **Single system node:** the default node pool is the AKS system pool. Microsoft requires at least two system nodes (three recommended) for *production* clusters; one node is accepted but has no redundancy, so use minimal mode for dev/test and POCs only.
- **Upgrades:** node upgrades surge one extra node, so allow vCPU quota for two nodes (32 vCPU of the DSv5 family for `Standard_D16s_v5`).
- **Pricing tier:** the cluster uses the Free tier (no uptime SLA), which Microsoft recommends for dev/test clusters with fewer than 10 nodes.

### Pod and service ranges

- `pod_cidr` and `service_cidr` must not overlap the VNet, peered VNets, ExpressRoute/VPN or on-prem ranges reachable from the cluster. An external host inside `pod_cidr` becomes unreachable from pods.
- AKS rejects the reserved ranges `169.254.0.0/16`, `192.0.2.0/24`, `172.30.0.0/16` and `172.31.0.0/16` (so `172.16.0.0/12` is not valid).
- Use RFC 1918 or RFC 6598 (`100.64.0.0/10`) space for `pod_cidr`. Each node takes a fixed `/24`: a `/20` covers 16 nodes.
- `service_cidr` must be smaller than a `/12`; a `/24` is plenty for AtScale. `dns_service_ip` must be inside it and not its first address.

### Egress

By default (`outbound_type = "loadBalancer"`) AKS creates a public IP for cluster egress. To send egress through your own firewall or NVA, set `outbound_type = "userDefinedRouting"` and `route_table_id` to an existing route table whose `0.0.0.0/0` route points to that firewall/NVA (not to `Internet`). The blueprint associates it with the node subnet before the cluster is created, which AKS validates.

## API Server Access

AKS nodes always run in private subnets. The API server (used by `kubectl`) can be either public or private:

| `public_api_server` | Behavior |
|---|---|
| `true` (default) | API server reachable from anywhere; secured by Azure AD authentication |
| `false` | API server reachable only from within the VNet; requires VPN or bastion host to run `kubectl` |

When setting `public_api_server = false`, set `authorized_network_cidr` to your VPN or office CIDR so those networks can reach the private endpoint.

## Ingress Gateway

With `enable_ingress_gateway = true` (the default), the cluster is created with
two add-ons so it can serve ingress without any further installation:

- **Managed Gateway API** - Azure installs and maintains the Gateway API CRDs.
- **Application Gateway for Containers (ALB) controller** - translates Gateway
  API and Ingress resources into Azure load balancing rules.

Enabling the ALB controller also turns on **workload identity**, which the
add-on requires to authenticate its controller.

The blueprint also provisions the infrastructure the association needs: a
dedicated subnet delegated to `Microsoft.ServiceNetworking/trafficControllers`
(a `/24` inside your VNet), and a `Network Contributor` role assignment giving
the ALB controller identity the `join` permission on it. The add-on does not
create these for a bring-your-own VNet, so they are part of the blueprint.

After the cluster is up, confirm the add-ons are running:

```sh
kubectl get pods -n kube-system | grep alb-controller
kubectl get gatewayclass azure-alb-external
```

### Default Application Gateway for Containers (optional)

By default the blueprint makes the cluster ingress-*ready* (subnet, role, and
the ALB controller) but does not provision an Application Gateway for Containers
- that is a billable Azure resource, so it is opt-in.

Set `create_default_alb = true` (or answer the matching prompt) and
`make create-cluster-azure` will, after the cluster is up, apply a default
`ApplicationLoadBalancer` for you and wait for the gateway to provision. It
prints the resulting `alb-id` to reference from your routes.

This step runs only through `make` - a bare `terraform apply` does not create
it, because the `ApplicationLoadBalancer` is a Kubernetes resource whose CRD is
installed by the add-on only after the cluster exists. The manifest is applied
by `scripts/apply-alb-manifest.sh` (namespace `alb-infra`, resource
`default-alb`).

### Wiring up traffic (day-2)

Whether the default ALB was created for you or you create your own, you still
define the routing:

1. If you did **not** set `create_default_alb`, create an
   `ApplicationLoadBalancer` resource whose `associations` reference the
   delegated subnet - this provisions the Application Gateway for Containers in
   Azure. Find the subnet ID with:
   ```sh
   az network vnet subnet show -g <resource_group> \
     --vnet-name <environment>-aks-vnet --name <environment>-alb-subnet \
     --query id -o tsv
   ```
2. A `Gateway` (or `Ingress`) that references the provisioned resource by its
   `alb-id`. For an `Ingress`, the association annotation is
   `alb.networking.azure.io/alb-id`, not `alb.networking.azure.io/alb-controller`.

See the [Application Gateway for Containers quickstart](https://learn.microsoft.com/azure/application-gateway/for-containers/quickstart-create-application-gateway-for-containers-managed-by-alb-controller).

Both add-ons are currently **in preview**:

- They require the subscription-level registrations listed under
  [Prerequisites](#prerequisites).
- Application Gateway for Containers is not available in every region. Check
  the [supported regions](https://learn.microsoft.com/azure/application-gateway/for-containers/overview#supported-regions)
  before choosing `region` - the add-on will enable anywhere, but provisioning
  the gateway resources fails in unsupported regions.
- Preview APIs can change between releases. The API version used to enable the
  ALB add-on is pinned in `alb_addon_api_version` so it can be moved forward
  without editing module code.

To deploy without them, set `enable_ingress_gateway = false`. The cluster is
then created exactly as before and you can install your own ingress controller.

## Storage

After the cluster is up, the Makefile applies an `azurefile-csi-nfs` StorageClass — Azure Files over the **NFS** protocol, backed by `file.csi.azure.com`, the CSI driver AKS ships by default. It provides **ReadWriteMany (RWX)** volumes.

> **Why NFS, not SMB:** AKS also ships a built-in `azurefile-csi` class that is RWX-capable, but it mounts shares over **SMB**. AtScale performs POSIX file operations (e.g. file locking, permission bits) against its shared logs volume that SMB does not support, so the RWX class **must** use the NFS protocol.

This is a **PROD requirement**: AtScale's shared logs volume needs RWX access from multiple pods. A dev/test install can run fine on a normal RWO class (the AKS-managed default Azure Disk class), since only a single pod mounts the volume.

Example PVC using the RWX class:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: atscale-logs
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: azurefile-csi-nfs
  resources:
    requests:
      storage: 100Gi
```

> **Note:** Premium Azure Files (required for NFS) has a 100Gi minimum share size — smaller PVC requests are rounded up by the driver.

If the StorageClass step didn't complete during `make create-cluster` (see the warning it prints), apply it manually:

```sh
az aks get-credentials --resource-group <resource_group> --name <cluster_name>
kubelogin convert-kubeconfig -l azurecli
bash ./scripts/apply-storageclass-manifest.sh
```

## Accessing the Cluster

After creation, connect to the cluster:

```sh
az aks get-credentials --resource-group <resource_group> --name <cluster_name>
kubelogin convert-kubeconfig -l azurecli
kubectl get nodes
```

## Database Access

The PostgreSQL database (if enabled) is deployed in a private subnet with no public access. Connection methods:

- Connect from within the VNet (e.g., from an AKS pod)
- Use a VPN connection into the VNet
- **Use the provided connection script:**

```sh
cd scripts
./connect-db.sh <DB_FQDN>
```

- **Or use a Kubernetes pod as a jump host:**

```sh
# Deploy a proxy pod
kubectl run db-proxy --image=alpine/socat --restart=Never -- \
  tcp-listen:5432,fork,reuseaddr tcp-connect:<DB_FQDN>:5432

# Port-forward to your local machine
kubectl port-forward pod/db-proxy 15432:5432

# Connect locally
psql -h localhost -p 15432 -U postgres
```

Get PostgreSQL credentials: `terraform output postgresql_credentials`

## Cleanup

```sh
make delete-cluster
```

Or manually: `terraform destroy`

## Troubleshooting

- Ensure your Azure credentials have sufficient permissions
- Verify you are logged in: `az login`
- If `kubectl` cannot connect after enabling a private API server, ensure you are accessing from within the Azure VNet
- Check the Azure Portal for resource status or review Terraform output for errors
