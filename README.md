# AtScale K8S Blueprints

This repository provides an automated way to create Kubernetes clusters using different cloud providers. This blueprint creates an environment with the default configuration to deploy AtScale applications correctly.

## Prerequisites

Before you begin, ensure you have the following tools installed and configured on your machine:

1. **AWS CLI**

   - Used for authentication and cluster access.
   - Download: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
   - You must have your AWS credentials configured (`aws configure`) with permissions to create EKS, VPC, and related resources.

2. **Terraform (>= 1.11.0)**

   - Used for infrastructure provisioning.
   - Download: https://www.terraform.io/downloads

3. **Make**
   - Used to run the provided Makefile commands.
   - macOS: Pre-installed.
   - Windows: Install via [Chocolatey](https://community.chocolatey.org/packages/make) or [GnuWin](http://gnuwin32.sourceforge.net/packages/make.htm).
   - Linux: Install via your package manager (e.g., `sudo apt-get install make`).

## Quick Start

1. **Clone this repository**

   ```sh
   git clone https://github.com/your-org/atscale-k8s-blueprints.git
   cd atscale-k8s-blueprints/environments/aws
   ```

2. **Configure Local Variables**
   Inside the `main.tf` file in the `environments/aws` directory, configure the required variables under the `locals` block:

   ```hcl
   environment  = "dev"                # Environment name (dev, staging, prod)
   vpc_cidr     = "10.20.0.0/22"      # VPC CIDR block for the cluster network
   region       = "us-west-2"         # AWS region to deploy resources
   ```

   The above shows the minimum required configuration. Additional variables can be customized:

   - EKS cluster settings (version, instance types, node counts)
   - RDS database configuration (if enabled)
   - SSO authentication settings
   - And more

   See the comments in `main.tf` for all available options and their descriptions.

3. **Create the EKS Cluster**

   ```sh
   make create-cluster
   ```

   This command will:

   - Initialize Terraform
   - Apply the VPC and EKS modules
   - Output the AWS CLI command needed to access your new cluster

4. **Access your EKS Cluster**
   After the cluster is created, the output will include a command similar to:
   ```sh
   aws eks update-kubeconfig --region <region> --name <cluster_name>
   ```
   Copy and run this command in your terminal to configure your `kubectl` context for the new cluster.

## What Gets Created

- A new VPC (Virtual Private Cloud)
- An EKS cluster
- All necessary IAM roles and security groups
- Optional: RDS resources and other AWS infrastructure as defined in the modules

## Notes

- The process may take several minutes, depending on your AWS region and resource quotas.
- You can customize the infrastructure by editing the Terraform modules in `modules/aws/`.
- To destroy the cluster and all resources, you can run:
  ```sh
  terraform destroy
  ```
  (from the `environments/aws` directory)

## Troubleshooting

- Ensure your AWS credentials have sufficient permissions.
- If you encounter issues, check the AWS Console for resource status or review the Terraform output for errors.

## Database Access

As this is a production-ready setup, the RDS database (if enabled) is deployed as a Multi-AZ cluster with no public internet access. To connect to the database securely, clients must use one of the following methods:

- Connect from within the same VPC (e.g., from an EKS pod or EC2 instance)
- Establish a VPN connection into the VPC
- Connect through a bastion host deployed within the VPC
- Use AWS Systems Manager Session Manager for secure shell access
- **Use a Kubernetes pod as a jump host (proxy) to access RDS from your local machine:**

### Accessing RDS from Your Local Machine via a Pod

Your RDS cluster is only accessible from within the EKS cluster's VPC. In order to connect to it, you can use a Kubernetes pod as a jump host. There are two main approaches:

#### **A. Exec into the Pod and Use psql**

1. Deploy a database proxy pod:
   ```sh
   kubectl run db-proxy --image=postgres:16 --env="PGPASSWORD=$DB_PASSWORD" --command -- sleep infinity
   ```
2. Exec into the pod:
   ```sh
   kubectl exec -it db-proxy -- bash
   ```
3. Connect to your RDS instance from inside the pod:
   ```sh
   psql -h <RDS_ENDPOINT> -U <DB_USER> -d <DB_NAME>
   ```
   Replace `<RDS_ENDPOINT>`, `<DB_USER>`, and `<DB_NAME>` with your actual RDS details. The password will be taken from the `PGPASSWORD` environment variable.

#### **B. Port-forward for Local or GUI Access**

If you want to use local tools (e.g., DBeaver, DataGrip) or connect from your local machine:

1. Deploy a pod with a TCP proxy (e.g., socat):
   ```sh
   kubectl run db-proxy --image=alpine/socat --restart=Never -- \
     tcp-listen:5432,fork,reuseaddr tcp-connect:<RDS_ENDPOINT>:5432
   ```
   Replace `<RDS_ENDPOINT>` with your RDS endpoint.
2. Port-forward from your local machine to the pod:
   ```sh
   kubectl port-forward pod/db-proxy 15432:5432
   ```
   This forwards your local port 15432 to the pod's port 5432, which is then proxied to RDS.
3. Connect from your local machine using your preferred tool:
   ```sh
   psql -h localhost -p 15432 -U <DB_USER> -d <DB_NAME>
   ```

---

The database endpoint and credentials can be retrieved using:

```sh
terraform output rds_credentials
```
