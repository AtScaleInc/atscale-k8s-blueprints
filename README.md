# AtScale EKS Blueprint

This repository provides an automated way to create an AWS EKS (Elastic Kubernetes Service) cluster to deploy your application.

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
   git clone https://github.com/your-org/atscale-eks-blueprint.git
   cd atscale-eks-blueprint/environments/aws
   ```

2. **Create the EKS Cluster**

   ```sh
   make create-cluster
   ```

   This command will:

   - Initialize Terraform
   - Apply the VPC and EKS modules
   - Output the AWS CLI command needed to access your new cluster

3. **Access your EKS Cluster**
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

## Support

For questions or support, please contact your AtScale representative or open an issue in this repository.

## Database Access

This blueprint creates a **private RDS cluster**. As a result, the database is not accessible from the public internet. To connect to the database, clients must use one of the following methods:

- Connect from within the same VPC (e.g., from an EC2 instance or EKS pod)
- Use a VPN connection into the VPC
- Use a bastion host deployed within the same VPC

This ensures that your database remains secure and isolated from external networks.
