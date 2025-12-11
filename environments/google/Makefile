.PHONY: create-cluster

create-cluster:
	terraform init
	terraform apply
	@echo
	@echo "GKE Cluster Access Instructions:"
	@echo "--------------------------------"
	@echo "To connect to this cluster, run: $$(terraform output -raw cluster_get_credentials_command)"
	@echo "--------------------------------"
	@if terraform output -raw database_public_ip 2>/dev/null | grep -q .; then \
		echo "To connect to the database, make sure you have the component gcloud cloud-sql-proxy installed and running,"; \
		echo "then run the following command:"; \
		echo "cloud-sql-proxy $$(terraform output -raw database_connection_name) --port=5432"; \
		echo "then you can connect to the database using the following information:"; \
		echo "Database URL: 127.0.0.1:5432"; \
		echo "Database User: $$(terraform output -raw database_user)"; \
		echo "Database Password: $$(terraform output -raw database_password)"; \
		echo "--------------------------------"; \
	fi
