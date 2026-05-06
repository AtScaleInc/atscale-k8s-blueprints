.PHONY: create-cluster delete-cluster plan

create-cluster:
	@NEED_BACKEND=false; \
	NEED_TFVARS=false; \
	if [ ! -f backend.tf ]; then \
		NEED_BACKEND=true; \
		echo ""; \
		echo "=== Step 1: Configure Terraform Backend ==="; \
		echo ""; \
		read -p "S3 bucket name for Terraform state: " BUCKET_NAME; \
		read -p "AWS Region [us-east-1]: " REGION; \
		REGION=$${REGION:-us-east-1}; \
		read -p "State file key [terraform/state]: " STATE_FILE_KEY; \
		STATE_FILE_KEY=$${STATE_FILE_KEY:-terraform/state}; \
		read -p "AWS CLI profile [default]: " AWS_PROFILE; \
		AWS_PROFILE=$${AWS_PROFILE:-default}; \
	fi; \
	if [ ! -f terraform.tfvars ]; then \
		NEED_TFVARS=true; \
		echo ""; \
		echo "=== Step 2: Configure Environment ==="; \
		echo ""; \
		read -p "Environment name (e.g., dev, staging, prod): " ENV_NAME; \
		read -p "AWS Region (e.g., us-east-1): " TF_REGION; \
		TF_REGION=$${TF_REGION:-$$REGION}; \
		read -p "VPC CIDR [10.84.0.0/20]: " VPC_CIDR; \
		VPC_CIDR=$${VPC_CIDR:-10.84.0.0/20}; \
		read -p "Kubernetes version [1.34]: " K8S_VERSION; \
		K8S_VERSION=$${K8S_VERSION:-1.34}; \
		read -p "Node instance type [m6a.xlarge]: " INSTANCE_TYPE; \
		INSTANCE_TYPE=$${INSTANCE_TYPE:-m6a.xlarge}; \
		echo ""; \
		echo "  Note: EKS nodes run in private subnets."; \
		echo "        You can choose whether the API server (kubectl endpoint) is public or private."; \
		echo ""; \
		read -p "Make API server publicly accessible? (true/false) [true]: " PUBLIC_API; \
		PUBLIC_API=$${PUBLIC_API:-true}; \
		if [ "$$PUBLIC_API" = "false" ]; then \
			echo ""; \
			echo "  NOTE: Private clusters use a two-phase deployment:"; \
			echo "    Phase 1: Deploy with a temporary public API endpoint"; \
			echo "    Phase 2: Switch the API endpoint to private"; \
			echo "  This is required because Terraform needs to reach the Kubernetes"; \
			echo "  API to provision in-cluster resources (e.g., StorageClasses)."; \
			echo "  The public endpoint is removed automatically once provisioning completes."; \
			echo ""; \
		fi; \
		read -p "Enable RDS PostgreSQL? (true/false) [false]: " ENABLE_RDS; \
		ENABLE_RDS=$${ENABLE_RDS:-false}; \
		echo ""; \
		echo "  Minimal cluster: 2 subnets (2 AZs) and 1 node — ideal for dev/test cost savings."; \
		read -p "Deploy minimal cluster? (true/false) [false]: " MINIMAL_CLUSTER; \
		MINIMAL_CLUSTER=$${MINIMAL_CLUSTER:-false}; \
	fi; \
	if [ "$$NEED_BACKEND" = "false" ] && [ "$$NEED_TFVARS" = "false" ]; then \
		echo "Backend and configuration already exist, proceeding with deployment..."; \
	else \
		echo ""; \
		echo "============================================"; \
		echo "  Deployment Summary"; \
		echo "============================================"; \
		echo ""; \
		if [ "$$NEED_BACKEND" = "true" ]; then \
			echo "  Terraform Backend (S3):"; \
			echo "    Bucket:      $$BUCKET_NAME"; \
			echo "    Region:      $$REGION"; \
			echo "    State key:   $$STATE_FILE_KEY"; \
			echo "    AWS Profile: $$AWS_PROFILE"; \
			echo ""; \
		else \
			echo "  Terraform Backend: already configured"; \
			echo ""; \
		fi; \
		if [ "$$NEED_TFVARS" = "true" ]; then \
			echo "  EKS Cluster:"; \
			echo "    Environment:     $$ENV_NAME"; \
			echo "    Region:          $$TF_REGION"; \
			echo "    VPC CIDR:        $$VPC_CIDR"; \
			echo "    Cluster name:    $${ENV_NAME}-eks"; \
			echo "    K8s version:     $$K8S_VERSION"; \
			echo "    Instance type:   $$INSTANCE_TYPE"; \
			echo "    Node count:      $$([ "$$MINIMAL_CLUSTER" = "true" ] && echo "1 (minimal)" || echo "3-6 (default)")"; \
			echo "    Subnets:         $$([ "$$MINIMAL_CLUSTER" = "true" ] && echo "4 across 2 AZs (minimal)" || echo "6 across 3 AZs (default)")"; \
			echo "    Spot instances:  enabled (default)"; \
			echo "    Nodes:           always private (private subnets)"; \
			echo "    API server:      $$([ "$$PUBLIC_API" = "false" ] && echo "private" || echo "public")"; \
			echo ""; \
			echo "  Database (RDS):"; \
			if [ "$$ENABLE_RDS" = "true" ]; then \
				echo "    Enabled:         yes"; \
				echo "    Engine:          PostgreSQL 16.11"; \
				echo "    Instance class:  db.r6gd.xlarge (default)"; \
				echo "    Storage:         250 GB (default)"; \
				echo "    Database name:   postgres"; \
				echo "    Username:        postgres"; \
			else \
				echo "    Enabled:         no"; \
			fi; \
			echo ""; \
		else \
			echo "  Configuration: using existing terraform.tfvars"; \
			echo ""; \
		fi; \
		echo "  (Edit variables.tf for all available options)"; \
		echo "============================================"; \
		echo ""; \
		read -p "Proceed with deployment? (yes/no): " CONFIRM; \
		if [ "$$CONFIRM" != "yes" ]; then \
			echo "Cancelled. No resources were created."; \
			exit 0; \
		fi; \
		echo ""; \
		if [ "$$NEED_BACKEND" = "true" ]; then \
			BUCKET_NAME=$$BUCKET_NAME REGION=$$REGION STATE_FILE_KEY=$$STATE_FILE_KEY \
				AWS_PROFILE=$$AWS_PROFILE bash ./bootstrap/bootstrap-tf-backend.sh; \
		fi; \
		if [ "$$NEED_TFVARS" = "true" ]; then \
			echo 'environment            = "'$$ENV_NAME'"' > terraform.tfvars; \
			echo 'region                 = "'$$TF_REGION'"' >> terraform.tfvars; \
			echo 'vpc_cidr               = "'$$VPC_CIDR'"' >> terraform.tfvars; \
			echo 'k8s_version            = "'$$K8S_VERSION'"' >> terraform.tfvars; \
			echo 'eks_instance_types     = ["'$$INSTANCE_TYPE'"]' >> terraform.tfvars; \
			echo 'public_api_server      = '$$PUBLIC_API >> terraform.tfvars; \
			echo 'enable_rds             = '$$ENABLE_RDS >> terraform.tfvars; \
			echo 'minimal_cluster        = '$$MINIMAL_CLUSTER >> terraform.tfvars; \
			echo "terraform.tfvars generated."; \
		fi; \
	fi; \
	IS_PRIVATE=false; \
	if grep -q 'public_api_server[[:space:]]*=[[:space:]]*false' terraform.tfvars 2>/dev/null; then \
		IS_PRIVATE=true; \
		echo ""; \
		echo "============================================"; \
		echo "  Private Cluster: Two-Phase Deployment"; \
		echo "============================================"; \
		echo ""; \
		echo "  Phase 1: Deploy with temporary public API endpoint"; \
		echo "           (Terraform must reach the K8s API to provision in-cluster resources)"; \
		echo "  Phase 2: Switch API endpoint to private (automatic)"; \
		echo ""; \
		sed -i.bak 's/public_api_server[[:space:]]*=.*/public_api_server      = true/' terraform.tfvars; \
		rm -f terraform.tfvars.bak; \
	fi; \
	terraform init && \
	echo "" && \
	echo "============================================" && \
	echo "  Generating Terraform plan (VPC)..." && \
	echo "============================================" && \
	echo "" && \
	terraform plan -out=tfplan --target=module.vpc && \
	echo "" && \
	read -p "Apply VPC resources? (yes/no): " APPLY_VPC; \
	if [ "$$APPLY_VPC" != "yes" ]; then \
		rm -f tfplan; \
		echo "Cancelled. No resources were created."; \
		exit 0; \
	fi; \
	terraform apply tfplan && \
	rm -f tfplan && \
	echo "" && \
	echo "============================================" && \
	echo "  Generating Terraform plan (full)..." && \
	echo "============================================" && \
	echo "" && \
	terraform plan -out=tfplan && \
	echo "" && \
	read -p "Apply this plan and create all resources? (yes/no): " APPLY_CONFIRM; \
	if [ "$$APPLY_CONFIRM" != "yes" ]; then \
		rm -f tfplan; \
		echo "Cancelled. VPC was created but EKS/RDS were not."; \
		exit 0; \
	fi; \
	terraform apply tfplan && \
	rm -f tfplan && \
	if [ "$$IS_PRIVATE" = "true" ]; then \
		echo "" && \
		echo "============================================" && \
		echo "  Private Cluster: Phase 2 of 2" && \
		echo "  Switching API endpoint to private..." && \
		echo "============================================" && \
		echo "" && \
		sed -i.bak 's/public_api_server[[:space:]]*=.*/public_api_server      = false/' terraform.tfvars && \
		rm -f terraform.tfvars.bak && \
		terraform plan -out=tfplan && \
		terraform apply tfplan && \
		rm -f tfplan; \
	fi && \
	echo "" && \
	echo "============================================" && \
	echo "  EKS Cluster Created Successfully!" && \
	echo "============================================" && \
	echo "" && \
	echo "Cluster: $$(terraform output -raw cluster_name)" && \
	echo "Region:  $$(terraform output -raw region)" && \
	echo "" && \
	echo "To connect to this cluster, run:" && \
	echo "  aws eks update-kubeconfig --region $$(terraform output -raw region) --name $$(terraform output -raw cluster_name)" && \
	echo "" && \
	if [ "$$IS_PRIVATE" = "true" ]; then \
		echo "NOTE: This is a private cluster. The API server is only reachable" && \
		echo "from within the VPC. To run kubectl commands, connect via:" && \
		echo "  - AWS Client VPN" && \
		echo "  - Bastion host in the VPC" && \
		echo "  - AWS Systems Manager Session Manager" && \
		echo ""; \
	fi && \
	echo "Verify with:" && \
	echo "  kubectl get nodes" && \
	echo "" && \
	if terraform output -json rds_credentials 2>/dev/null | grep -q endpoint; then \
		echo "RDS credentials: terraform output rds_credentials"; \
	fi

delete-cluster:
	@echo "WARNING: This will destroy ALL resources including any databases and data."
	@read -p "Are you sure? (yes/no): " CONFIRM; \
	if [ "$$CONFIRM" = "yes" ]; then \
		terraform destroy; \
		echo ""; \
		echo "Cluster deleted successfully."; \
	else \
		echo "Cancelled."; \
	fi

plan:
	terraform init
	terraform plan
