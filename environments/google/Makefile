.PHONY: create-cluster delete-cluster plan

create-cluster:
	@NEED_BACKEND=false; \
	NEED_TFVARS=false; \
	if [ ! -f backend.tf ]; then \
		NEED_BACKEND=true; \
		echo ""; \
		echo "=== Step 1: Configure Terraform Backend ==="; \
		echo ""; \
		read -p "GCP Project ID: " PROJECT_ID; \
		read -p "GCS bucket name for Terraform state: " BUCKET_NAME; \
		read -p "GCP Region [us-central1]: " LOCATION; \
		LOCATION=$${LOCATION:-us-central1}; \
		read -p "State file prefix [terraform/state]: " STATE_FILE_PREFIX; \
		STATE_FILE_PREFIX=$${STATE_FILE_PREFIX:-terraform/state}; \
	fi; \
	if [ ! -f terraform.tfvars ]; then \
		NEED_TFVARS=true; \
		echo ""; \
		echo "=== Step 2: Configure Environment Variables ==="; \
		echo ""; \
		read -p "Environment name (e.g., dev, staging, prod): " ENV_NAME; \
		read -p "GCP Project ID: " PROJECT_ID; \
		PROJECT_ID=$${PROJECT_ID:-$$PROJECT_ID}; \
		read -p "GKE GCP Region [us-central1]: " REGION; \
		REGION=$${REGION:-us-central1}; \
		read -p "Cluster name: " CLUSTER_NAME; \
		read -p "Kubernetes version (e.g., 1.33): " K8S_VERSION; \
		K8S_VERSION=$${K8S_VERSION:-1.33}; \
		read -p "Node instance type [n2d-standard-4]: " INSTANCE_TYPE; \
		INSTANCE_TYPE=$${INSTANCE_TYPE:-n2d-standard-4}; \
		echo ""; \
		echo "Network CIDR Configuration:"; \
		echo "  GKE requires three non-overlapping CIDR ranges."; \
		echo "  Recommended: 10.0.0.0/20 (nodes), 10.1.0.0/16 (pods), 10.2.0.0/20 (services)"; \
		echo ""; \
		read -p "Node subnet CIDR [10.0.0.0/20]: " SUBNET_CIDR; \
		SUBNET_CIDR=$${SUBNET_CIDR:-10.0.0.0/20}; \
		read -p "Pods secondary range CIDR [10.1.0.0/16]: " PODS_CIDR; \
		PODS_CIDR=$${PODS_CIDR:-10.1.0.0/16}; \
		read -p "Services secondary range CIDR [10.2.0.0/20]: " SERVICES_CIDR; \
		SERVICES_CIDR=$${SERVICES_CIDR:-10.2.0.0/20}; \
		echo ""; \
		echo "  Note: GKE nodes are always private (no public IPs)."; \
		echo "        You can choose whether the API server (kubectl endpoint) is public or private."; \
		echo ""; \
		read -p "Make API server publicly accessible? (true/false) [true]: " PUBLIC_API; \
		PUBLIC_API=$${PUBLIC_API:-true}; \
		AUTHORIZED_CIDR=""; \
		if [ "$$PUBLIC_API" = "false" ]; then \
			echo ""; \
			echo "  NOTE: Private clusters use a two-phase deployment:"; \
			echo "    Phase 1: Deploy with a temporary public API endpoint"; \
			echo "    Phase 2: Switch the API endpoint to private"; \
			echo "  This is required because Terraform needs to reach the Kubernetes"; \
			echo "  API to provision in-cluster resources (e.g., StorageClasses)."; \
			echo "  The public endpoint is removed automatically once provisioning completes."; \
			echo ""; \
			read -p "CIDR allowed to access the private API server (e.g., 10.0.0.0/8): " AUTHORIZED_CIDR; \
		fi; \
		read -p "Enable Cloud SQL PostgreSQL? (true/false) [false]: " ENABLE_DB; \
		ENABLE_DB=$${ENABLE_DB:-false}; \
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
			echo "  Terraform Backend (GCS):"; \
			echo "    Project:      $$PROJECT_ID"; \
			echo "    Bucket:       $$BUCKET_NAME"; \
			echo "    Region:       $$LOCATION"; \
			echo "    State prefix: $$STATE_FILE_PREFIX"; \
			echo ""; \
		else \
			echo "  Terraform Backend: already configured"; \
			echo ""; \
		fi; \
		if [ "$$NEED_TFVARS" = "true" ]; then \
			echo "  GKE Cluster:"; \
			echo "    Project:         $$PROJECT_ID"; \
			echo "    Environment:     $$ENV_NAME"; \
			echo "    Region:          $$REGION"; \
			echo "    Cluster name:    $$CLUSTER_NAME"; \
			echo "    K8s version:     $$K8S_VERSION"; \
			echo "    Instance type:   $$INSTANCE_TYPE"; \
			echo "    Node count:      1-3 (default)"; \
			echo "    Spot instances:  enabled (default)"; \
			echo "    Nodes:           always private (no public IPs)"; \
			echo "    API server:      $$([ "$$PUBLIC_API" = "false" ] && echo "private (CIDR: $$AUTHORIZED_CIDR)" || echo "public")"; \
			echo ""; \
			echo "  Network CIDRs:"; \
			echo "    Node subnet:     $$SUBNET_CIDR"; \
			echo "    Pods range:      $$PODS_CIDR"; \
			echo "    Services range:  $$SERVICES_CIDR"; \
			echo ""; \
			echo "  Database (Cloud SQL):"; \
			if [ "$$ENABLE_DB" = "true" ]; then \
				echo "    Enabled:         yes"; \
				echo "    Engine:          PostgreSQL 16"; \
				echo "    Tier:            db-f1-micro (default)"; \
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
			PROJECT_ID=$$PROJECT_ID \
			BUCKET_NAME=$$BUCKET_NAME \
			LOCATION=$$LOCATION \
			STATE_FILE_PREFIX=$$STATE_FILE_PREFIX \
			bash ./bootstrap/bootstrap-tf-backend.sh; \
		fi; \
		if [ "$$NEED_TFVARS" = "true" ]; then \
			echo 'environment                   = "'$$ENV_NAME'"' > terraform.tfvars; \
			echo 'project_id                    = "'$$PROJECT_ID'"' >> terraform.tfvars; \
			echo 'region                        = "'$$REGION'"' >> terraform.tfvars; \
			echo 'cluster_name                  = "'$$CLUSTER_NAME'"' >> terraform.tfvars; \
			echo 'subnet_cidr                   = "'$$SUBNET_CIDR'"' >> terraform.tfvars; \
			echo 'pods_secondary_range_cidr     = "'$$PODS_CIDR'"' >> terraform.tfvars; \
			echo 'services_secondary_range_cidr = "'$$SERVICES_CIDR'"' >> terraform.tfvars; \
			echo 'public_api_server             = '$$PUBLIC_API >> terraform.tfvars; \
			echo 'authorized_network_cidr       = "'$$AUTHORIZED_CIDR'"' >> terraform.tfvars; \
			echo 'enable_postgres_database      = '$$ENABLE_DB >> terraform.tfvars; \
			echo 'k8s_version                   = "'$$K8S_VERSION'"' >> terraform.tfvars; \
			echo 'gke_instance_types            = ["'$$INSTANCE_TYPE'"]' >> terraform.tfvars; \
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
		sed -i.bak 's/public_api_server[[:space:]]*=.*/public_api_server             = true/' terraform.tfvars; \
		rm -f terraform.tfvars.bak; \
	fi; \
	terraform init && \
	echo "" && \
	echo "============================================" && \
	echo "  Generating Terraform plan..." && \
	echo "============================================" && \
	echo "" && \
	terraform plan -out=tfplan && \
	echo "" && \
	read -p "Apply this plan and create resources? (yes/no): " APPLY_CONFIRM; \
	if [ "$$APPLY_CONFIRM" != "yes" ]; then \
		rm -f tfplan; \
		echo "Cancelled. No resources were created."; \
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
		sed -i.bak 's/public_api_server[[:space:]]*=.*/public_api_server             = false/' terraform.tfvars && \
		rm -f terraform.tfvars.bak && \
		terraform plan -out=tfplan && \
		terraform apply tfplan && \
		rm -f tfplan; \
	fi && \
	echo "" && \
	echo "============================================" && \
	echo "  GKE Cluster Created Successfully!" && \
	echo "============================================" && \
	echo "" && \
	echo "Cluster: $$(terraform output -raw cluster_name)" && \
	echo "Region:  $$(terraform output -raw region)" && \
	echo "Project: $$(terraform output -raw project_id)" && \
	echo "" && \
	echo "To connect to this cluster, run:" && \
	echo "  $$(terraform output -raw cluster_get_credentials_command)" && \
	echo "" && \
	if [ "$$IS_PRIVATE" = "true" ]; then \
		echo "NOTE: This is a private cluster. The API server is only reachable" && \
		echo "from within the VPC. To run kubectl commands, connect via:" && \
		echo "  - Cloud VPN or Cloud Interconnect" && \
		echo "  - Bastion host in the VPC" && \
		echo "  - Identity-Aware Proxy (IAP) tunnel" && \
		echo ""; \
	fi && \
	echo "Verify with:" && \
	echo "  kubectl get nodes" && \
	echo "" && \
	if terraform output -raw database_private_ip 2>/dev/null | grep -q .; then \
		echo "Database connection (private IP, accessible from within the VPC):"; \
		echo "  Private IP:   $$(terraform output -raw database_private_ip)"; \
		echo "  Database:     $$(terraform output -raw database_name)"; \
		echo "  User:         $$(terraform output -raw database_user)"; \
		echo "  Password:     terraform output -raw database_password"; \
		echo ""; \
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

