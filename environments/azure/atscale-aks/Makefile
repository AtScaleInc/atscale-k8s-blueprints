.PHONY: create-cluster

create-cluster:
	terraform init
	terraform apply
	@echo
	@echo "AKS Cluster Access Instructions:"
	@echo "--------------------------------"
	@echo "To connect to this cluster, run the following commands:"
	@echo "az aks get-credentials --resource-group $$(terraform output -raw resource_group_name) --name $$(terraform output -raw aks_name)"
	@echo "kubelogin convert-kubeconfig -l azurecli"
	@echo "kubectl get nodes"
	@echo
	@if terraform output -json | jq -e '.postgresql_credentials.value != null' > /dev/null; then \
		echo "PostgreSQL Server Credentials:"; \
		echo "-------------------------------"; \
		echo "FQDN: $$(terraform output -json postgresql_credentials | jq -r '.fqdn')"; \
		echo "Username: $$(terraform output -json postgresql_credentials | jq -r '.username')"; \
		echo "Password: $$(terraform output -json postgresql_credentials | jq -r '.password')"; \
	else \
		echo "PostgreSQL server is not created."; \
	fi

delete-cluster:
	terraform destroy
	@echo
	@echo "Cluster deleted successfully."