.PHONY: create-cluster

create-cluster:
	terraform init
	terraform apply
	@echo
	@echo "GKE Cluster Access Instructions:"
	@echo "--------------------------------"
	@echo "To connect to this cluster, run: $$(terraform output -raw cluster_get_credentials_command)"

