# AtScale K8S Blueprint - Azure (AKS)

This blueprint creates an AKS (Azure Kubernetes Service) cluster on Azure with networking, storage, and optional database resources.

## What Gets Created

- Virtual Network (VNet) with subnets for AKS and optional PostgreSQL
- AKS cluster with RBAC and Azure AD integration (nodes always in private subnets)
- Log Analytics workspace
- Network Security Groups
- Gateway API and Application Gateway for Containers add-ons, so the cluster can serve ingress out of the box (see [Ingress gateway](#ingress-gateway))
- Optional: Azure PostgreSQL Flexible Server with private networking

## Prerequisites

1. **Azure CLI** - [Install](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
2. **kubelogin** - [Install](https://github.com/Azure/kubelogin)
3. **Terraform >= 1.11.0** - [Install](https://www.terraform.io/downloads)
4. **Make** - Pre-installed on macOS/Linux
5. **kubectl** - [Install](https://kubernetes.io/docs/tasks/tools/)

6. **Preview features for the ingress gateway add-ons** (only if `enable_ingress_gateway = true`, which is the default):

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

## Quick Start

```sh
cd environments/azure
make create-cluster
```

The Makefile guides you through the full deployment in two phases:

**Phase 1 — Configuration (nothing is created yet):**
1. Prompts for Terraform backend settings (Azure Storage Account for state)
2. Prompts for cluster settings (environment, region, resource group, VNet CIDR, K8s version, VM size, API access, PostgreSQL)
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
| `vpc_cidr` | VNet address space | `"10.85.0.0/22"` |
| `resource_group_name` | Azure resource group | `"rg-atscale-dev"` |
| `aad_admin_group_object_id` | AAD admin group ID | `"12345-abcde-..."` |

**Optional variables** (have sensible defaults):

| Variable | Default | Description |
|----------|---------|-------------|
| `aks_version` | `"1.34"` | AKS Kubernetes version |
| `aks_node_count` | `3` | Number of worker nodes |
| `aks_node_size` | `"Standard_D8s_v5"` | VM size for nodes |
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

### Wiring up traffic (day-2)

The blueprint makes the cluster ingress-*ready* but does not define your
routing. To serve traffic you still create, in the cluster:

1. An `ApplicationLoadBalancer` resource whose `associations` reference the
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
