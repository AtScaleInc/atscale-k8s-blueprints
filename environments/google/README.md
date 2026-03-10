# AtScale K8S Blueprint - Google Cloud (GKE)

This blueprint creates a GKE (Google Kubernetes Engine) cluster on Google Cloud with networking, storage, and optional database resources.

## What Gets Created

- VPC with custom subnet and secondary IP ranges for pods and services
- Cloud Router and Cloud NAT for outbound internet access
- Firewall rules for internal traffic
- GKE cluster with autoscaling node pool (nodes always private — no external IPs)
- Filestore CSI driver for persistent storage
- Workload Identity for IAM integration
- Optional: Cloud SQL PostgreSQL instance

## Prerequisites

1. **Google Cloud SDK (gcloud)** - [Install](https://cloud.google.com/sdk/docs/install)
2. **Terraform >= 1.11.0** - [Install](https://www.terraform.io/downloads)
3. **Make** - Pre-installed on macOS/Linux
4. **kubectl** - [Install](https://kubernetes.io/docs/tasks/tools/)

Verify prerequisites:

```sh
bash ../../scripts/check-prerequisites.sh google
```

## Quick Start

```sh
cd environments/google
make create-cluster
```

The Makefile guides you through the full deployment in two phases:

**Phase 1 — Configuration (nothing is created yet):**
1. Prompts for Terraform backend settings (GCS bucket for state)
2. Prompts for cluster settings (environment, project, region, CIDRs, K8s version, instance type, API access, database)
3. Displays a full deployment summary
4. Asks: `Proceed with deployment? (yes/no)` — only on "yes" does anything happen

**Phase 2 — Deployment:**
1. Creates the GCS bucket backend and generates `terraform.tfvars`
2. Runs `terraform plan`, asks for confirmation, applies everything
3. Prints cluster access instructions

## Configuration

All configuration is managed through `terraform.tfvars`. The Makefile generates this file interactively on first run. You can also create or edit it manually.

**Required variables** (no defaults, prompted by Makefile):

| Variable                        | Description      | Example            |
| ------------------------------- | ---------------- | ------------------ |
| `environment`                   | Environment name | `"dev"`            |
| `project_id`                    | GCP project ID   | `"my-project-123"` |
| `region`                        | GCP region       | `"us-central1"`    |
| `cluster_name`                  | GKE cluster name | `"dev-gke"`        |
| `subnet_cidr`                   | Node subnet CIDR | `"10.0.0.0/20"`    |
| `pods_secondary_range_cidr`     | Pod IP range     | `"10.1.0.0/16"`    |
| `services_secondary_range_cidr` | Service IP range | `"10.2.0.0/20"`    |

### Understanding GKE Network CIDRs

GKE requires three non-overlapping CIDR ranges:

| CIDR                            | Purpose            | Recommended Size   | Example       |
| ------------------------------- | ------------------ | ------------------ | ------------- |
| `subnet_cidr`                   | Node IPs           | `/20` (4,094 IPs)  | `10.0.0.0/20` |
| `pods_secondary_range_cidr`     | Pod IPs            | `/16` (65,534 IPs) | `10.1.0.0/16` |
| `services_secondary_range_cidr` | Service ClusterIPs | `/20` (4,094 IPs)  | `10.2.0.0/20` |

**Sizing rules:**

- The pods range must be significantly larger than the nodes range because GKE assigns a `/24` from the pods range to each node
- For a 3-node cluster: minimum `/22` for pods, but `/16` is recommended for growth
- Services range: `/20` supports ~4,000 services, which is sufficient for most deployments
- **None of these ranges should overlap** with each other

**Optional variables** (have sensible defaults):

| Variable                             | Default               | Description                                              |
| ------------------------------------ | --------------------- | -------------------------------------------------------- |
| `k8s_version`                        | `"1.33"`              | GKE Kubernetes version                                   |
| `gke_instance_types`                 | `["n2d-standard-4"]`  | Worker node machine types                                |
| `gke_workers_min_instance_count`     | `1`                   | Minimum worker nodes                                     |
| `gke_workers_max_instance_count`     | `3`                   | Maximum worker nodes                                     |
| `gke_workers_desired_instance_count` | `1`                   | Initial worker nodes                                     |
| `enable_spot_instances`              | `true`                | Use preemptible instances                                |
| `public_api_server`                  | `true`                | Make the GKE API server publicly accessible              |
| `authorized_network_cidr`            | `""`                  | CIDR allowed to reach the API server when it is private  |
| `enable_postgres_database`           | `true`                | Create Cloud SQL PostgreSQL                              |
| `database_version`                   | `"POSTGRES_16"`       | PostgreSQL version                                       |
| `database_tier`                      | `"db-f1-micro"`       | Cloud SQL instance tier                                  |
| `database_name`                      | `"postgres"`          | Database name                                            |
| `database_user`                      | `"postgres"`          | Database username                                        |
| `filestore_tier`                     | `"BASIC_SSD"`         | Filestore tier                                           |

See `variables.tf` for the complete list of options.

## API Server Access

GKE nodes always run without external IPs (private nodes). The API server (used by `kubectl`) can be either public or private:

| `public_api_server` | Behavior |
|---|---|
| `true` (default) | API server reachable from anywhere; secured by GCP IAM authentication |
| `false` | API server reachable only from within the VPC; requires VPN or bastion host to run `kubectl` |

When setting `public_api_server = false`, set `authorized_network_cidr` to your VPN or office CIDR so those networks can reach the private endpoint.

> **Note:** The private API server endpoint will have an IP in the `172.16.0.0/28` range. Your machine must be inside the GCP VPC (via Cloud VPN or bastion) to reach it.

### Private Cluster Deployment

When `public_api_server = false`, the Makefile automatically performs a **two-phase deployment**:

1. **Phase 1** — Deploys the cluster with a temporary public API endpoint. This is required because Terraform needs to reach the Kubernetes API to provision in-cluster resources (e.g., Filestore StorageClass).
2. **Phase 2** — Switches the API endpoint to private and applies the change. The public endpoint is removed automatically.

No manual intervention is needed — the Makefile handles both phases transparently.

## Accessing the Cluster

After creation, connect to the cluster:

```sh
gcloud container clusters get-credentials <cluster_name> --region <region> --project <project_id>
kubectl get nodes
```

## Database Access

The Cloud SQL database (if enabled) can be accessed via:

- **Cloud SQL Proxy (recommended):**

  ```sh
  cloud-sql-proxy <CONNECTION_NAME> --port=5432
  psql -h 127.0.0.1 -p 5432 -U postgres -d postgres
  ```

- **From within the VPC** (e.g., from a GKE pod)

Get database credentials from Terraform output:

```sh
terraform output -raw database_password
```

## Cleanup

```sh
make delete-cluster
```

Or manually: `terraform destroy`

> **Private clusters:** If `public_api_server = false`, you must run `terraform destroy` from a machine that can reach the VPC (e.g., via Cloud VPN, bastion host, or IAP tunnel). Terraform needs access to the Kubernetes API to delete in-cluster resources like StorageClasses.

## Troubleshooting

- Ensure GCP credentials are configured: `gcloud auth login` and `gcloud auth application-default login`
- Verify required APIs are enabled: Compute Engine, Kubernetes Engine, Cloud SQL, Cloud Filestore
- If `kubectl` cannot connect after enabling a private API server, ensure you are accessing from within the GCP VPC
- Check the Google Cloud Console for resource status or review Terraform output for errors
