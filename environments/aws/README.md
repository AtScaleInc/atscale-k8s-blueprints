# AtScale K8S Blueprint - AWS (EKS)

This blueprint creates an EKS (Elastic Kubernetes Service) cluster on AWS with networking, storage, and optional database resources.

## What Gets Created

- VPC with 3 private and 3 public subnets across 3 availability zones
- NAT gateway for private subnet internet access
- VPC endpoints (S3, STS, EC2, ECR, CloudWatch Logs)
- EKS cluster with managed node group (nodes always in private subnets)
- EFS file system with mount targets in all private subnets
- Kubernetes StorageClasses (EFS and EBS)
- IAM roles for IRSA and service access
- Optional: RDS PostgreSQL Multi-AZ cluster with RDS Proxy

## Prerequisites

1. **AWS CLI** - [Install](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
2. **Terraform >= 1.11.0** - [Install](https://www.terraform.io/downloads)
3. **Make** - Pre-installed on macOS/Linux
4. **kubectl** - [Install](https://kubernetes.io/docs/tasks/tools/)

Verify prerequisites:
```sh
bash ../../scripts/check-prerequisites.sh aws
```

## Quick Start

```sh
cd environments/aws
make create-cluster
```

The Makefile guides you through the full deployment in two phases:

**Phase 1 — Configuration (nothing is created yet):**
1. Prompts for Terraform backend settings (S3 bucket for state)
2. Prompts for cluster settings (environment, region, VPC CIDR, K8s version, instance type, API access, RDS)
3. Displays a full deployment summary
4. Asks: `Proceed with deployment? (yes/no)` — only on "yes" does anything happen

**Phase 2 — Deployment:**
1. Creates the S3 backend and generates `terraform.tfvars`
2. Runs `terraform plan` scoped to the VPC, asks for confirmation, applies VPC
3. Runs `terraform plan` for the full cluster, asks for confirmation, applies everything
4. Prints cluster access instructions

## Configuration

All configuration is managed through `terraform.tfvars`. The Makefile generates this file interactively on first run. You can also create or edit it manually.

**Required variables** (no defaults, prompted by Makefile):

| Variable | Description | Example |
|----------|-------------|---------|
| `environment` | Environment name | `"dev"` |
| `region` | AWS region | `"us-east-1"` |
| `vpc_cidr` | VPC CIDR block | `"10.84.0.0/22"` |

**Optional variables** (have sensible defaults):

| Variable | Default | Description |
|----------|---------|-------------|
| `k8s_version` | `"1.34"` | EKS Kubernetes version |
| `eks_instance_types` | `["m6a.4xlarge", "m6i.4xlarge", "m5.4xlarge"]` | Worker node instance types |
| `eks_workers_min_instance_count` | `3` | Minimum worker nodes |
| `eks_workers_max_instance_count` | `6` | Maximum worker nodes |
| `eks_workers_desired_instance_count` | `3` | Desired worker nodes |
| `enable_spot_instances` | `true` | Use spot instances for cost savings |
| `public_api_server` | `true` | Make the EKS API server publicly accessible |
| `authorized_network_cidr` | `""` | CIDR allowed to reach the API server when `public_api_server = false` |
| `enable_rds` | `false` | Create RDS PostgreSQL instance |
| `rds_engine_version` | `"16.11"` | PostgreSQL version |
| `rds_instance_class` | `"db.r6gd.xlarge"` | RDS instance class |
| `rds_db_name` | `"postgres"` | Database name |
| `rds_username` | `"postgres"` | Database username |

See `variables.tf` for the complete list of options.

## API Server Access

EKS nodes always run in private subnets. The API server (used by `kubectl`) can be either public or private:

| `public_api_server` | Behavior |
|---|---|
| `true` (default) | API server reachable from anywhere; secured by IAM authentication |
| `false` | API server reachable only from within the VPC; requires VPN or bastion host to run `kubectl` |

When setting `public_api_server = false`, set `authorized_network_cidr` to your VPC or VPN CIDR so internal traffic can reach the endpoint.

## Accessing the Cluster

After creation, connect to the cluster:

```sh
aws eks update-kubeconfig --region <region> --name <cluster_name>
kubectl get nodes
```

## Database Access

The RDS database (if enabled) is deployed in private subnets with no public access. Connection methods:

- Connect from within the VPC (e.g., from an EKS pod)
- Use a VPN connection into the VPC
- Use AWS Systems Manager Session Manager
- **Use a Kubernetes pod as a jump host:**

```sh
# Deploy a proxy pod
kubectl run db-proxy --image=alpine/socat --restart=Never -- \
  tcp-listen:5432,fork,reuseaddr tcp-connect:<RDS_ENDPOINT>:5432

# Port-forward to your local machine
kubectl port-forward pod/db-proxy 15432:5432

# Connect locally
psql -h localhost -p 15432 -U postgres -d postgres
```

Get RDS credentials: `terraform output rds_credentials`

## Cleanup

```sh
make delete-cluster
```

Or manually: `terraform destroy`

## Troubleshooting

- Ensure your AWS credentials have sufficient permissions
- If facing spot instance availability issues, set `enable_spot_instances = false`
- Check the AWS Console for resource status or review Terraform output for errors
