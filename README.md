# Atscale K8S Blueprints

Automated Kubernetes cluster provisioning for AtScale applications across major cloud providers. Designed for non-technical users to deploy production-ready infrastructure with a single command.

## Supported Cloud Providers

| Provider     | Service                          | Guide                                        |
| ------------ | -------------------------------- | -------------------------------------------- |
| AWS          | EKS (Elastic Kubernetes Service) | [Setup Guide](environments/aws/README.md)    |
| Google Cloud | GKE (Google Kubernetes Engine)   | [Setup Guide](environments/google/README.md) |
| Azure        | AKS (Azure Kubernetes Service)   | [Setup Guide](environments/azure/README.md)  |

## Quick Start

Run the appropriate target from the repo root and follow the interactive prompts:

```sh
# AWS
make create-cluster-aws

# Google Cloud
make create-cluster-gcp

# Azure
make create-cluster-azure
```

Run `make help` to see all available targets.

The Makefile will:

- Prompt for all required configuration (backend, cluster, database, API access)
- Display a full summary of what will be created
- Ask for confirmation before touching any cloud resources
- Set up the Terraform state backend automatically
- Generate a `terraform.tfvars` file from your inputs
- Run `terraform plan` so you can review the exact changes
- Ask for a final confirmation before applying
- Print cluster access instructions when done

## Prerequisites

Each cloud provider requires its own CLI tool. Run the prerequisites check before starting:

```sh
# Check for AWS prerequisites
make check-prerequisites-aws

# Check for Google Cloud prerequisites
make check-prerequisites-gcp

# Check for Azure prerequisites
make check-prerequisites-azure
```

Common requirements:

- **Terraform >= 1.11.0** - [Install](https://www.terraform.io/downloads)
- **Make** - Pre-installed on macOS/Linux
- **kubectl** - [Install](https://kubernetes.io/docs/tasks/tools/)
- **jq** - [Install](https://jqlang.github.io/jq/download/)

## What Gets Created

Each blueprint provisions:

- A cloud-native VPC/VNet with properly configured subnets
- A managed Kubernetes cluster with autoscaling node pools
- Storage classes for persistent storage (EFS, Filestore, etc.)
- IAM roles and security groups with least-privilege access
- Optional: Managed PostgreSQL database (RDS, Cloud SQL, Azure PostgreSQL)

See the provider-specific READMEs for detailed resource lists.

## Configuration

All user configuration is managed through `terraform.tfvars` files. The Makefile generates this file — along with the Terraform backend configuration (`backend.tf`) — interactively on first run.

If you prefer to skip the interactive prompts, you can create both files manually before running the `make create-cluster-*` command. The Makefile detects their presence and proceeds straight to deployment. Templates and instructions are available in each provider's README:

- [AWS manual setup](environments/aws/README.md#manual-setup-skip-interactive-prompts)

See `variables.tf` in each environment directory for all available options with descriptions and defaults.

## Cleanup

Each provider has a safe deletion command:

```sh
make delete-cluster-aws
make delete-cluster-gcp
make delete-cluster-azure
```

These will prompt for confirmation before destroying resources.

> **Warning (AWS):** Before running `make delete-cluster-aws`, remove all Kubernetes `LoadBalancer` services and `Ingress` resources from the cluster. The AWS Load Balancer Controller provisions real AWS load balancers (ALBs, NLBs, Classic ELBs) that are **not tracked by Terraform**. If they still exist when `terraform destroy` runs, it will time out trying to delete the VPC.
>
> ```sh
> kubectl delete svc --all-namespaces --field-selector spec.type=LoadBalancer
> kubectl delete ingress --all --all-namespaces
> ```
>
> Wait a minute for AWS to fully decommission the load balancers before proceeding.

## Project Structure

```
atscale-k8s-blueprints/
├── environments/
│   ├── aws/               # AWS EKS configuration
│   ├── google/            # Google Cloud GKE configuration
│   └── azure/             # Azure AKS configuration
├── modules/
│   ├── aws/               # AWS Terraform modules
│   ├── gke/               # GKE Terraform modules
│   └── azure/             # Azure Terraform modules
└── scripts/
    └── check-prerequisites.sh
```
