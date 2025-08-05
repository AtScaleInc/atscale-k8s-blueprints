.PHONY: create-cluster

create-cluster:
	terraform init
	terraform apply --target=module.vpc
	terraform apply
	@echo
	@echo "EKS Cluster Access Instructions:"
	@echo "--------------------------------"
	@echo "To connect to this cluster, run: aws eks update-kubeconfig --region $$(terraform output -raw region) --name $$(terraform output -raw cluster_name)"
	@echo "If you deployed an RDS cluster, you can get its credentials running the following command: terraform output rds_credentials"