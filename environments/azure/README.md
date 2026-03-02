# AtScale K8S Blueprint - Azure (AKS)

This blueprint creates an AKS (Azure Kubernetes Service) cluster on Azure with networking, storage, and optional database resources.

## What Gets Created

- Virtual Network (VNet) with subnets for AKS and optional PostgreSQL
- AKS cluster with RBAC and Azure AD integration (nodes always in private subnets)
- Log Analytics workspace
- Network Security Groups
- Optional: Azure PostgreSQL Flexible Server with private networking

## Prerequisites

1. **Azure CLI** - [Install](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
2. **kubelogin** - [Install](https://github.com/Azure/kubelogin)
3. **Terraform >= 1.11.0** - [Install](https://www.terraform.io/downloads)
4. **Make** - Pre-installed on macOS/Linux
5. **kubectl** - [Install](https://kubernetes.io/docs/tasks/tools/)

Verify prerequisites:
```sh
bash ../../scripts/check-prerequisites.sh azure
```

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
| `aks_version` | `"1.31"` | AKS Kubernetes version |
| `aks_node_count` | `3` | Number of worker nodes |
| `aks_node_size` | `"Standard_D8s_v5"` | VM size for nodes |
| `public_api_server` | `true` | Make the AKS API server publicly accessible |
| `authorized_network_cidr` | `""` | CIDR allowed to reach the API server when `public_api_server = false` |
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
