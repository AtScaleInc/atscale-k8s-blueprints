# AtScale K8S Blueprint - AWS (EKS)

This blueprint creates an EKS (Elastic Kubernetes Service) cluster on AWS with networking, storage, and optional database resources.

## What Gets Created

- VPC with 6 subnets (3 private + 3 public) across 3 availability zones, or 4 subnets (2 private + 2 public) across 2 AZs in minimal mode
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

All configuration is managed through `terraform.tfvars`. The Makefile generates this file interactively on first run. Alternatively, you can create both files manually before running `make create-cluster` to skip the interactive prompts entirely — the Makefile detects their presence and proceeds straight to deployment.

### Manual Setup (skip interactive prompts)

**1. Create `backend.tf`** in `environments/aws/`:

```hcl
terraform {
  required_version = ">= 1.11.0"

  backend "s3" {
    bucket       = "<YOUR_S3_BUCKET>"
    key          = "<YOUR_STATE_KEY>"   # e.g. terraform/state
    region       = "<YOUR_REGION>"
    profile      = "<YOUR_AWS_PROFILE>" # defaults to "default"
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.19.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.4"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = "<YOUR_AWS_PROFILE>"

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "terraform"
      Project     = "${var.environment}-tf"
    }
  }
}

provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.region, "--profile", "<YOUR_AWS_PROFILE>"]
    command     = "aws"
  }
}
```

> The S3 bucket must already exist. If it doesn't, run `bootstrap/bootstrap-tf-backend.sh` or create it manually with versioning and server-side encryption enabled.

**2. Create `terraform.tfvars`** in `environments/aws/`:

```hcl
environment             = "dev"
region                  = "us-east-1"
vpc_cidr                = "10.84.0.0/20"
k8s_version             = "1.34"
eks_instance_types      = ["m6a.4xlarge"]
public_api_server       = true
enable_rds              = false
minimal_cluster         = false
```

Once both files are in place, run `make create-cluster` and it will proceed directly to `terraform init` and deployment.

**Available variables:**

**Required variables** (no defaults, prompted by Makefile):

| Variable | Description | Example |
|----------|-------------|---------|
| `environment` | Environment name | `"dev"` |
| `region` | AWS region | `"us-east-1"` |
| `vpc_cidr` | VPC CIDR block. Must be `/22` or larger and a valid network address (no host bits set). | `"10.84.0.0/22"` |

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
| `minimal_cluster` | `false` | Deploy with 4 subnets across 2 AZs and 1 node for dev/test cost savings. Requires at least `m6a.4xlarge` — all AtScale components must fit on a single node. |
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

### Private Cluster Deployment

When `public_api_server = false`, the Makefile automatically performs a **two-phase deployment**:

1. **Phase 1** — Deploys the cluster with a temporary public API endpoint. This is required because Terraform needs to reach the Kubernetes API to provision in-cluster resources (e.g., StorageClasses).
2. **Phase 2** — Switches the API endpoint to private and applies the change. The public endpoint is removed automatically.

No manual intervention is needed — the Makefile handles both phases transparently.

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

> **Warning:** Before deleting the cluster, make sure all Kubernetes `LoadBalancer` services and `Ingress` resources have been removed from the cluster. These cause the AWS Load Balancer Controller to provision real AWS load balancers (ALBs, NLBs, Classic ELBs) that are **not tracked by Terraform**. If they still exist when `terraform destroy` runs, it will time out trying to delete the VPC because the load balancers hold references to its subnets and security groups.
>
> To remove them:
> ```sh
> # Delete all LoadBalancer-type services
> kubectl delete svc --all-namespaces --field-selector spec.type=LoadBalancer
>
> # Delete all Ingress resources
> kubectl delete ingress --all --all-namespaces
> ```
> Wait a minute for AWS to fully decommission the load balancers before proceeding.

```sh
make delete-cluster
```

Or manually: `terraform destroy`

> **Private clusters:** If `public_api_server = false`, you must run `terraform destroy` from a machine that can reach the VPC (e.g., via VPN, bastion host, or SSM). Terraform needs access to the Kubernetes API to delete in-cluster resources like StorageClasses.

## Troubleshooting

- Ensure your AWS credentials have sufficient permissions
- If facing spot instance availability issues, set `enable_spot_instances = false`
- Check the AWS Console for resource status or review Terraform output for errors

### VPC CIDR requirements

The `vpc_cidr` must meet two conditions:

1. **Minimum size `/22`** — the subnets are carved as `/prefix+3` blocks. A `/22` produces `/25` subnets (123 usable IPs each). Smaller CIDRs like `/23` or `/24` leave too few IPs for EKS nodes and pods (AWS VPC CNI assigns a VPC IP to every pod).
2. **Valid network address** — the host bits must be zero. For example, `10.230.187.0/22` is invalid because 187 is not aligned to a `/22` boundary; the correct address is `10.230.184.0/22` (184 is the nearest multiple of 4).

Terraform will reject invalid values at plan time with a descriptive error message.

### Minimal cluster instance type

When `minimal_cluster = true`, all AtScale components are scheduled on a single node. An `m6a.4xlarge` (16 vCPU / 64 GB RAM) is the recommended minimum. Smaller instance types will likely result in pods stuck in `Pending` due to insufficient resources.
