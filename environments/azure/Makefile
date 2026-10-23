.PHONY: create-cluster delete-cluster plan

create-cluster:
	@NEED_BACKEND=false; \
	NEED_TFVARS=false; \
	if [ ! -f backend.tf ]; then \
		NEED_BACKEND=true; \
		echo ""; \
		echo "=== Step 1: Configure Terraform Backend ==="; \
		echo ""; \
		DEFAULT_SUBSCRIPTION_ID=$$(az account show --query id -o tsv 2>/dev/null); \
		DEFAULT_SUBSCRIPTION_NAME=$$(az account show --query name -o tsv 2>/dev/null); \
		if [ -n "$$DEFAULT_SUBSCRIPTION_ID" ]; then \
			echo "  Current Azure subscription: $$DEFAULT_SUBSCRIPTION_NAME ($$DEFAULT_SUBSCRIPTION_ID)"; \
			echo ""; \
		fi; \
		read -p "Azure Subscription ID [$$DEFAULT_SUBSCRIPTION_ID]: " SUBSCRIPTION_ID; \
		SUBSCRIPTION_ID=$${SUBSCRIPTION_ID:-$$DEFAULT_SUBSCRIPTION_ID}; \
		read -p "Resource group name for TF state: " RESOURCE_GROUP_NAME; \
		read -p "Azure Region [eastus]: " LOCATION; \
		LOCATION=$${LOCATION:-eastus}; \
		read -p "Storage account name (lowercase, alphanumeric): " STORAGE_ACCOUNT_NAME; \
		read -p "Container name [tfstate]: " CONTAINER_NAME; \
		CONTAINER_NAME=$${CONTAINER_NAME:-tfstate}; \
		read -p "State file name [terraform.tfstate]: " STATE_FILE_NAME; \
		STATE_FILE_NAME=$${STATE_FILE_NAME:-terraform.tfstate}; \
		echo ""; \
		echo "  Note: the state storage account is created without account keys or anonymous access,"; \
		echo "        so every request needs your Entra ID identity. Network access can be:"; \
		echo "          public   - reachable from any network (default)"; \
		echo "          firewall - only from the IP ranges you allow"; \
		echo "          private  - public access disabled; private endpoint in an existing subnet."; \
		echo "                     Terraform must then run from a network that can reach it."; \
		echo ""; \
		read -p "State network access (public/firewall/private) [public]: " TFSTATE_NETWORK_ACCESS; \
		TFSTATE_NETWORK_ACCESS=$${TFSTATE_NETWORK_ACCESS:-public}; \
		PRIVATE_ENDPOINT_SUBNET_ID=""; \
		PRIVATE_DNS_ZONE_ID=""; \
		if [ "$$TFSTATE_NETWORK_ACCESS" = "firewall" ]; then \
			read -p "Allowed IP ranges, comma-separated (Enter to detect your public IP) [$$ALLOWED_IP_RANGES]: " INPUT_IP_RANGES; \
			ALLOWED_IP_RANGES=$${INPUT_IP_RANGES:-$$ALLOWED_IP_RANGES}; \
		fi; \
		if [ "$$TFSTATE_NETWORK_ACCESS" = "private" ]; then \
			read -p "Private endpoint subnet ID: " PRIVATE_ENDPOINT_SUBNET_ID; \
			read -p "privatelink.blob.core.windows.net zone ID (optional, Enter to skip): " PRIVATE_DNS_ZONE_ID; \
		fi; \
	fi; \
	if [ ! -f terraform.tfvars ]; then \
		NEED_TFVARS=true; \
		echo ""; \
		echo "=== Step 2: Configure Environment ==="; \
		echo ""; \
		read -p "Environment name (e.g., dev, staging, prod): " ENV_NAME; \
		DEFAULT_REGION=$${LOCATION:-eastus}; \
		read -p "Azure Region [$$DEFAULT_REGION]: " REGION; \
		REGION=$${REGION:-$$DEFAULT_REGION}; \
		if [ -n "$$RESOURCE_GROUP_NAME" ]; then \
			read -p "Resource group name [$$RESOURCE_GROUP_NAME]: " RESOURCE_GROUP; \
			RESOURCE_GROUP=$${RESOURCE_GROUP:-$$RESOURCE_GROUP_NAME}; \
		else \
			read -p "Resource group name: " RESOURCE_GROUP; \
		fi; \
		echo ""; \
		echo "  Note: by default a new VNet is created in the resource group above."; \
		echo "        To use an existing VNet (e.g., a spoke peered to your hub), enter its name;"; \
		echo "        the blueprint then creates its subnets, from the VNet CIDR below, inside it."; \
		echo ""; \
		read -p "Existing VNet name (optional, Enter to create a new VNet): " EXISTING_VNET; \
		EXISTING_VNET_RG=""; \
		if [ -n "$$EXISTING_VNET" ]; then \
			read -p "Existing VNet resource group [$$RESOURCE_GROUP]: " EXISTING_VNET_RG; \
			EXISTING_VNET_RG=$${EXISTING_VNET_RG:-$$RESOURCE_GROUP}; \
		fi; \
		echo ""; \
		echo "  Minimal cluster: 1 node, no ingress gateway add-ons - for dev/test and POCs."; \
		echo "  The VNet can then be as small as a /26."; \
		read -p "Deploy minimal cluster? (true/false) [true]: " MINIMAL_CLUSTER; \
		MINIMAL_CLUSTER=$${MINIMAL_CLUSTER:-true}; \
		echo ""; \
		if [ "$$MINIMAL_CLUSTER" = "true" ]; then \
			echo "  Note: Minimal clusters require at least a Standard_D16s_v5 (16 vCPU / 64 GB)"; \
			echo "        to run all AtScale components on a single node. Smaller sizes will likely fail."; \
			echo ""; \
			read -p "VNet CIDR (free range in the VNet if existing), /26 or larger (e.g., 10.85.0.0/26): " VPC_CIDR; \
			DEFAULT_VM_SIZE=Standard_D16s_v5; \
		else \
			read -p "VNet CIDR (free range in the VNet if existing), /22 or larger with the ingress gateway (e.g., 10.85.0.0/22): " VPC_CIDR; \
			DEFAULT_VM_SIZE=Standard_D8s_v5; \
		fi; \
		echo ""; \
		echo "  Note: you (the identity running Terraform) are made cluster admin automatically."; \
		echo "        Optionally add an Entra ID group so other people get admin access too."; \
		echo ""; \
		read -p "AAD admin group object ID (optional, Enter to skip): " AAD_GROUP; \
		read -p "Kubernetes version [1.35]: " K8S_VERSION; \
		K8S_VERSION=$${K8S_VERSION:-1.35}; \
		read -p "Node VM size [$$DEFAULT_VM_SIZE]: " VM_SIZE; \
		VM_SIZE=$${VM_SIZE:-$$DEFAULT_VM_SIZE}; \
		NODE_COUNT=$$([ "$$MINIMAL_CLUSTER" = "true" ] && echo 1 || echo 3); \
		while ! bash ./scripts/check-vm-quota.sh "$$REGION" "$$VM_SIZE" "$$NODE_COUNT" "$$SUBSCRIPTION_ID"; do \
			read -p "Node VM size (Enter to keep $$VM_SIZE anyway): " NEW_VM_SIZE; \
			[ -z "$$NEW_VM_SIZE" ] && break; \
			VM_SIZE=$$NEW_VM_SIZE; \
		done; \
		echo ""; \
		echo "  Note: pod and service ranges use no VNet addresses, but must not overlap the"; \
		echo "        VNet, peered VNets, ExpressRoute/VPN or on-prem ranges, nor the AKS-reserved"; \
		echo "        169.254.0.0/16, 192.0.2.0/24, 172.30.0.0/16 and 172.31.0.0/16."; \
		echo ""; \
		read -p "Pod CIDR (overlay, /24 per node) [10.244.0.0/16]: " POD_CIDR; \
		POD_CIDR=$${POD_CIDR:-10.244.0.0/16}; \
		read -p "Service CIDR (smaller than /12) [10.0.0.0/16]: " SERVICE_CIDR; \
		SERVICE_CIDR=$${SERVICE_CIDR:-10.0.0.0/16}; \
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
		ENABLE_INGRESS=false; \
		if [ "$$MINIMAL_CLUSTER" != "true" ]; then \
			echo ""; \
			echo "  Note: the ingress gateway add-ons (Gateway API + Application Gateway"; \
			echo "        for Containers) let the cluster serve ingress out of the box."; \
			echo "        They are in PREVIEW and need preview features registered on the"; \
			echo "        subscription - see the README prerequisites. Leave them off if"; \
			echo "        preview features are not allowed or you don't use Gateway API."; \
			echo ""; \
			read -p "Enable ingress gateway add-ons (preview)? (true/false) [false]: " ENABLE_INGRESS; \
			ENABLE_INGRESS=$${ENABLE_INGRESS:-false}; \
		fi; \
		CREATE_ALB=false; \
		if [ "$$ENABLE_INGRESS" = "true" ]; then \
			echo ""; \
			echo "  Optional: also create a default Application Gateway for Containers"; \
			echo "            after the cluster is up, so ingress works with no further"; \
			echo "            steps. This provisions a BILLABLE Azure resource."; \
			echo ""; \
			read -p "Create a default Application Gateway for Containers? (true/false) [false]: " CREATE_ALB; \
			CREATE_ALB=$${CREATE_ALB:-false}; \
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
			if [ "$$TFSTATE_NETWORK_ACCESS" = "private" ]; then \
				NETWORK_ACCESS_DESC="private endpoint (public access disabled)"; \
			elif [ "$$TFSTATE_NETWORK_ACCESS" = "firewall" ]; then \
				NETWORK_ACCESS_DESC="firewall ($${ALLOWED_IP_RANGES:-your detected public IP})"; \
			else \
				NETWORK_ACCESS_DESC="public (Entra ID auth required)"; \
			fi; \
			echo "    Network access:  $$NETWORK_ACCESS_DESC"; \
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
			echo "    VNet:            $$([ -n "$$EXISTING_VNET" ] && echo "existing $$EXISTING_VNET (RG $$EXISTING_VNET_RG)" || echo "new")"; \
			echo "    VNet CIDR:       $$VPC_CIDR"; \
			echo "    Cluster admins:  you (deployer)$$([ -n "$$AAD_GROUP" ] && echo " + AAD group $$AAD_GROUP")"; \
			echo "    K8s version:     $$K8S_VERSION"; \
			echo "    VM size:         $$VM_SIZE"; \
			echo "    Node count:      $$([ "$$MINIMAL_CLUSTER" = "true" ] && echo "1 (minimal)" || echo "3 (default)")"; \
			echo "    Pod CIDR:        $$POD_CIDR (overlay)"; \
			echo "    Service CIDR:    $$SERVICE_CIDR"; \
			echo "    Nodes:           always private (private subnets)"; \
			echo "    API server:      $$([ "$$PUBLIC_API" = "false" ] && echo "private (CIDR: $$AUTHORIZED_CIDR)" || echo "public")"; \
			echo "    Ingress gateway: $$([ "$$ENABLE_INGRESS" = "false" ] && echo "no" || echo "yes (Gateway API + ALB controller, preview)")"; \
			echo "    Default AGC:     $$([ "$$CREATE_ALB" = "true" ] && echo "yes (billable Application Gateway for Containers)" || echo "no")"; \
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
				TFSTATE_NETWORK_ACCESS=$$TFSTATE_NETWORK_ACCESS ALLOWED_IP_RANGES=$$ALLOWED_IP_RANGES \
				PRIVATE_ENDPOINT_SUBNET_ID=$$PRIVATE_ENDPOINT_SUBNET_ID PRIVATE_DNS_ZONE_ID=$$PRIVATE_DNS_ZONE_ID \
				bash ./bootstrap/bootstrap-tf-backend.sh || { \
				echo ""; \
				echo "ERROR: Terraform backend bootstrap failed. Nothing else was created."; \
				echo "       If Azure reported an MFA error, sign in again completing MFA:"; \
				echo "         az logout && az login --tenant $$(az account show --query tenantId -o tsv 2>/dev/null)"; \
				echo "       then re-run: make create-cluster-azure"; \
				exit 1; \
			}; \
		fi; \
		if [ "$$NEED_TFVARS" = "true" ]; then \
			echo 'environment                = "'$$ENV_NAME'"' > terraform.tfvars; \
			echo 'region                     = "'$$REGION'"' >> terraform.tfvars; \
			echo 'resource_group_name        = "'$$RESOURCE_GROUP'"' >> terraform.tfvars; \
			echo 'vpc_cidr                   = "'$$VPC_CIDR'"' >> terraform.tfvars; \
			if [ -n "$$EXISTING_VNET" ]; then \
				echo 'existing_vnet_name                = "'$$EXISTING_VNET'"' >> terraform.tfvars; \
				echo 'existing_vnet_resource_group_name = "'$$EXISTING_VNET_RG'"' >> terraform.tfvars; \
			fi; \
			echo 'minimal_cluster            = '$$MINIMAL_CLUSTER >> terraform.tfvars; \
			echo 'pod_cidr                   = "'$$POD_CIDR'"' >> terraform.tfvars; \
			echo 'service_cidr               = "'$$SERVICE_CIDR'"' >> terraform.tfvars; \
			echo 'aad_admin_group_object_id  = "'$$AAD_GROUP'"' >> terraform.tfvars; \
			echo 'aks_version                = "'$$K8S_VERSION'"' >> terraform.tfvars; \
			echo 'aks_node_size              = "'$$VM_SIZE'"' >> terraform.tfvars; \
			echo 'public_api_server          = '$$PUBLIC_API >> terraform.tfvars; \
			echo 'authorized_network_cidr    = "'$$AUTHORIZED_CIDR'"' >> terraform.tfvars; \
			echo 'enable_ingress_gateway     = '$$ENABLE_INGRESS >> terraform.tfvars; \
			echo 'create_default_alb         = '$$CREATE_ALB >> terraform.tfvars; \
			echo 'enable_postgresql          = '$$ENABLE_PG >> terraform.tfvars; \
			echo "terraform.tfvars generated."; \
		fi; \
	fi; \
	CLUSTER_RG=$$(sed -n 's/^resource_group_name *= *"\(.*\)"/\1/p' terraform.tfvars); \
	CLUSTER_REGION=$$(sed -n 's/^region *= *"\(.*\)"/\1/p' terraform.tfvars); \
	if [ -n "$$CLUSTER_RG" ] && ! az group show --name "$$CLUSTER_RG" >/dev/null 2>&1; then \
		echo "Creating resource group $$CLUSTER_RG in $$CLUSTER_REGION..."; \
		az group create --name "$$CLUSTER_RG" --location "$$CLUSTER_REGION" -o none || exit 1; \
	fi; \
	terraform init || { \
		echo ""; \
		echo "ERROR: terraform init failed (see above). No cluster resources were created."; \
		exit 1; \
	}; \
	echo ""; \
	echo "============================================"; \
	echo "  Generating Terraform plan (Networking)..."; \
	echo "============================================"; \
	echo ""; \
	terraform plan -out=tfplan --target=module.networking || { \
		rm -f tfplan; \
		echo ""; \
		echo "ERROR: the networking plan failed (see above). No cluster resources were created."; \
		exit 1; \
	}; \
	echo ""; \
	read -p "Apply networking resources? (yes/no): " APPLY_NET; \
	if [ "$$APPLY_NET" != "yes" ]; then \
		rm -f tfplan; \
		echo "Cancelled. No resources were created."; \
		exit 0; \
	fi; \
	terraform apply tfplan || { \
		rm -f tfplan; \
		echo ""; \
		echo "ERROR: applying the networking resources failed (see above). Some may have been"; \
		echo "       created; fix the error and re-run make create-cluster-azure to continue."; \
		exit 1; \
	}; \
	rm -f tfplan; \
	echo ""; \
	echo "============================================"; \
	echo "  Generating Terraform plan (full)..."; \
	echo "============================================"; \
	echo ""; \
	terraform plan -out=tfplan || { \
		rm -f tfplan; \
		echo ""; \
		echo "ERROR: the full plan failed (see above). Networking was created but AKS/PostgreSQL"; \
		echo "       were not; fix the error and re-run make create-cluster-azure to continue."; \
		exit 1; \
	}; \
	echo ""; \
	read -p "Apply this plan and create all resources? (yes/no): " APPLY_CONFIRM; \
	if [ "$$APPLY_CONFIRM" != "yes" ]; then \
		rm -f tfplan; \
		echo "Cancelled. Networking was created but AKS/PostgreSQL were not."; \
		exit 0; \
	fi; \
	terraform apply tfplan || { \
		rm -f tfplan; \
		echo ""; \
		echo "ERROR: creating the cluster resources failed (see above). Some may have been"; \
		echo "       created; fix the error and re-run make create-cluster-azure to continue."; \
		exit 1; \
	}; \
	rm -f tfplan; \
	echo ""; \
	echo "============================================"; \
	echo "  Configuring Azure Files StorageClass for RWX volumes..." && \
	echo "============================================" && \
	echo "" && \
	if az aks get-credentials \
			--resource-group "$$(terraform output -raw resource_group_name)" \
			--name "$$(terraform output -raw aks_name)" --overwrite-existing \
		&& kubelogin convert-kubeconfig -l azurecli \
		&& bash ./scripts/wait-for-cluster-admin.sh \
		&& bash ./scripts/apply-storageclass-manifest.sh; then \
		true; \
	else \
		echo ""; \
		echo "WARNING: applying the azurefile-csi-nfs StorageClass did not complete."; \
		echo "         The cluster itself was created successfully. Retry with:"; \
		echo "           az aks get-credentials --resource-group $$(terraform output -raw resource_group_name) --name $$(terraform output -raw aks_name)"; \
		echo "           kubelogin convert-kubeconfig -l azurecli"; \
		echo "           bash ./scripts/wait-for-cluster-admin.sh"; \
		echo "           bash ./scripts/apply-storageclass-manifest.sh"; \
	fi && \
	if [ "$$(terraform output -raw create_default_alb 2>/dev/null)" = "true" ]; then \
		echo ""; \
		echo "============================================"; \
		echo "  Provisioning default Application Gateway for Containers..."; \
		echo "============================================"; \
		echo ""; \
		if az aks get-credentials \
				--resource-group "$$(terraform output -raw resource_group_name)" \
				--name "$$(terraform output -raw aks_name)" --overwrite-existing \
			&& kubelogin convert-kubeconfig -l azurecli \
			&& bash ./scripts/apply-alb-manifest.sh "$$(terraform output -raw alb_subnet_id)"; then \
			true; \
		else \
			echo ""; \
			echo "WARNING: the default Application Gateway for Containers bootstrap did not complete."; \
			echo "         The cluster itself was created successfully. Retry the ALB step with:"; \
			echo "           make create-cluster   (re-runs the ALB step; it is idempotent)"; \
			echo "         or apply it manually:"; \
			echo "           bash ./scripts/apply-alb-manifest.sh $$(terraform output -raw alb_subnet_id 2>/dev/null)"; \
		fi; \
	fi && \
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
	if [ "$$CONFIRM" != "yes" ]; then \
		echo "Cancelled."; \
		exit 0; \
	fi; \
	if [ "$$(terraform output -raw create_default_alb 2>/dev/null)" = "true" ]; then \
		echo "Removing the default Application Gateway for Containers before destroy..."; \
		echo "(the ApplicationLoadBalancer is not in Terraform state; deleting it first releases"; \
		echo " its association on the delegated subnet so 'terraform destroy' does not fail)"; \
		if az aks get-credentials \
				--resource-group "$$(terraform output -raw resource_group_name)" \
				--name "$$(terraform output -raw aks_name)" --overwrite-existing 2>/dev/null \
			&& kubelogin convert-kubeconfig -l azurecli 2>/dev/null; then \
			kubectl delete applicationloadbalancer default-alb -n alb-infra \
				--ignore-not-found --timeout=300s \
				|| echo "WARNING: ALB cleanup did not finish; 'terraform destroy' may fail on the subnet - if so, remove the resource group with: az group delete -n $$(terraform output -raw resource_group_name)"; \
		else \
			echo "WARNING: could not reach the cluster to remove the ALB resource first."; \
			echo "         'terraform destroy' may fail on the association subnet; if so, use:"; \
			echo "           az group delete -n $$(terraform output -raw resource_group_name)"; \
		fi; \
	fi; \
	terraform destroy && \
	echo "" && \
	echo "Cluster deleted successfully."

plan:
	terraform init
	terraform plan
