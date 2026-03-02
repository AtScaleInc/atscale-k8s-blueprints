.PHONY: create-cluster delete-cluster plan

create-cluster:
	@NEED_BACKEND=false; \
	NEED_TFVARS=false; \
	if [ ! -f backend.tf ]; then \
		NEED_BACKEND=true; \
		echo ""; \
		echo "=== Step 1: Configure Terraform Backend ==="; \
		echo ""; \
		read -p "Azure Subscription ID: " SUBSCRIPTION_ID; \
		read -p "Resource group name for TF state: " RESOURCE_GROUP_NAME; \
		read -p "Azure Region (e.g., eastus, westus3): " LOCATION; \
		read -p "Storage account name (lowercase, alphanumeric): " STORAGE_ACCOUNT_NAME; \
		read -p "Container name [tfstate]: " CONTAINER_NAME; \
		CONTAINER_NAME=$${CONTAINER_NAME:-tfstate}; \
		read -p "State file name [terraform.tfstate]: " STATE_FILE_NAME; \
		STATE_FILE_NAME=$${STATE_FILE_NAME:-terraform.tfstate}; \
	fi; \
	if [ ! -f terraform.tfvars ]; then \
		NEED_TFVARS=true; \
		echo ""; \
		echo "=== Step 2: Configure Environment ==="; \
		echo ""; \
		read -p "Environment name (e.g., dev, staging, prod): " ENV_NAME; \
		read -p "Azure Region (e.g., eastus, westus3): " REGION; \
		read -p "Resource group name: " RESOURCE_GROUP; \
		read -p "VNet CIDR (e.g., 10.85.0.0/22): " VPC_CIDR; \
		read -p "AAD admin group object ID: " AAD_GROUP; \
		read -p "Kubernetes version [1.31]: " K8S_VERSION; \
		K8S_VERSION=$${K8S_VERSION:-1.31}; \
		read -p "Node VM size [Standard_D8s_v5]: " VM_SIZE; \
		VM_SIZE=$${VM_SIZE:-Standard_D8s_v5}; \
		echo ""; \
		echo "  Note: AKS nodes run in private subnets."; \
		echo "        You can choose whether the API server (kubectl endpoint) is public or private."; \
		echo ""; \
		read -p "Make API server publicly accessible? (true/false) [true]: " PUBLIC_API; \
		PUBLIC_API=$${PUBLIC_API:-true}; \
		AUTHORIZED_CIDR=""; \
		if [ "$$PUBLIC_API" = "false" ]; then \
			read -p "CIDR allowed to access the private API server (e.g., 10.0.0.0/8): " AUTHORIZED_CIDR; \
		fi; \
		read -p "Enable PostgreSQL? (true/false) [false]: " ENABLE_PG; \
		ENABLE_PG=$${ENABLE_PG:-false}; \
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
			echo "  Terraform Backend (Azure Storage):"; \
			echo "    Subscription:    $$SUBSCRIPTION_ID"; \
			echo "    Resource group:  $$RESOURCE_GROUP_NAME"; \
			echo "    Region:          $$LOCATION"; \
			echo "    Storage account: $$STORAGE_ACCOUNT_NAME"; \
			echo "    Container:       $$CONTAINER_NAME"; \
			echo "    State file:      $$STATE_FILE_NAME"; \
			echo ""; \
		else \
			echo "  Terraform Backend: already configured"; \
			echo ""; \
		fi; \
		if [ "$$NEED_TFVARS" = "true" ]; then \
			echo "  AKS Cluster:"; \
			echo "    Environment:     $$ENV_NAME"; \
			echo "    Region:          $$REGION"; \
			echo "    Resource group:  $$RESOURCE_GROUP"; \
			echo "    VNet CIDR:       $$VPC_CIDR"; \
			echo "    AAD group:       $$AAD_GROUP"; \
			echo "    K8s version:     $$K8S_VERSION"; \
			echo "    VM size:         $$VM_SIZE"; \
			echo "    Node count:      3 (default)"; \
			echo "    Nodes:           always private (private subnets)"; \
			echo "    API server:      $$([ "$$PUBLIC_API" = "false" ] && echo "private (CIDR: $$AUTHORIZED_CIDR)" || echo "public")"; \
			echo ""; \
			echo "  Database (PostgreSQL Flexible Server):"; \
			if [ "$$ENABLE_PG" = "true" ]; then \
				echo "    Enabled:         yes"; \
				echo "    Version:         16"; \
				echo "    SKU:             GP_Standard_D4ads_v5 (default)"; \
				echo "    Storage:         64 GB (default)"; \
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
			RESOURCE_GROUP_NAME=$$RESOURCE_GROUP_NAME LOCATION=$$LOCATION \
				STORAGE_ACCOUNT_NAME=$$STORAGE_ACCOUNT_NAME CONTAINER_NAME=$$CONTAINER_NAME \
				STATE_FILE_NAME=$$STATE_FILE_NAME SUBSCRIPTION_ID=$$SUBSCRIPTION_ID \
				bash ./bootstrap/bootstrap-tf-backend.sh; \
		fi; \
		if [ "$$NEED_TFVARS" = "true" ]; then \
			echo 'environment                = "'$$ENV_NAME'"' > terraform.tfvars; \
			echo 'region                     = "'$$REGION'"' >> terraform.tfvars; \
			echo 'resource_group_name        = "'$$RESOURCE_GROUP'"' >> terraform.tfvars; \
			echo 'vpc_cidr                   = "'$$VPC_CIDR'"' >> terraform.tfvars; \
			echo 'aad_admin_group_object_id  = "'$$AAD_GROUP'"' >> terraform.tfvars; \
			echo 'aks_version                = "'$$K8S_VERSION'"' >> terraform.tfvars; \
			echo 'aks_node_size              = "'$$VM_SIZE'"' >> terraform.tfvars; \
			echo 'public_api_server          = '$$PUBLIC_API >> terraform.tfvars; \
			echo 'authorized_network_cidr    = "'$$AUTHORIZED_CIDR'"' >> terraform.tfvars; \
			echo 'enable_postgresql          = '$$ENABLE_PG >> terraform.tfvars; \
			echo "terraform.tfvars generated."; \
		fi; \
	fi; \
	terraform init && \
	echo "" && \
	echo "============================================" && \
	echo "  Generating Terraform plan (Networking)..." && \
	echo "============================================" && \
	echo "" && \
	terraform plan -out=tfplan --target=module.networking && \
	echo "" && \
	read -p "Apply networking resources? (yes/no): " APPLY_NET; \
	if [ "$$APPLY_NET" != "yes" ]; then \
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
		echo "Cancelled. Networking was created but AKS/PostgreSQL were not."; \
		exit 0; \
	fi; \
	terraform apply tfplan && \
	rm -f tfplan && \
	echo "" && \
	echo "============================================" && \
	echo "  AKS Cluster Created Successfully!" && \
	echo "============================================" && \
	echo "" && \
	echo "Cluster: $$(terraform output -raw aks_name)" && \
	echo "Region:  $$(terraform output -raw region)" && \
	echo "" && \
	echo "To connect to this cluster, run:" && \
	echo "  az aks get-credentials --resource-group $$(terraform output -raw resource_group_name) --name $$(terraform output -raw aks_name)" && \
	echo "  kubelogin convert-kubeconfig -l azurecli" && \
	echo "" && \
	echo "Verify with:" && \
	echo "  kubectl get nodes" && \
	echo "" && \
	if terraform output -json postgresql_credentials 2>/dev/null | grep -q fqdn; then \
		echo "PostgreSQL credentials: terraform output postgresql_credentials"; \
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
