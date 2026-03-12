.PHONY: create-cluster-aws create-cluster-gcp create-cluster-azure \
       delete-cluster-aws delete-cluster-gcp delete-cluster-azure \
       check-prerequisites-aws check-prerequisites-gcp check-prerequisites-azure help

help:
	@echo "AtScale K8S Blueprints"
	@echo "====================="
	@echo ""
	@echo "Available targets:"
	@echo ""
	@echo "  Create clusters:"
	@echo "    make create-cluster-aws     Create an EKS cluster on AWS"
	@echo "    make create-cluster-gcp     Create a GKE cluster on Google Cloud"
	@echo "    make create-cluster-azure   Create an AKS cluster on Azure"
	@echo ""
	@echo "  Delete clusters:"
	@echo "    make delete-cluster-aws     Destroy the AWS EKS cluster"
	@echo "    make delete-cluster-gcp     Destroy the GCP GKE cluster"
	@echo "    make delete-cluster-azure   Destroy the Azure AKS cluster"
	@echo ""
	@echo "  Utilities:"
	@echo "    make check-prerequisites-aws    Check AWS prerequisites"
	@echo "    make check-prerequisites-gcp    Check GCP prerequisites"
	@echo "    make check-prerequisites-azure  Check Azure prerequisites"
	@echo "    make fetch-latest               Check for updates"
	@echo ""

# AWS
create-cluster-aws: check-prerequisites-aws
	@$(MAKE) -C environments/aws create-cluster

delete-cluster-aws:
	@$(MAKE) -C environments/aws delete-cluster

check-prerequisites-aws:
	@bash scripts/check-prerequisites.sh aws

# Google Cloud
create-cluster-gcp: check-prerequisites-gcp
	@$(MAKE) -C environments/google create-cluster

delete-cluster-gcp:
	@$(MAKE) -C environments/google delete-cluster

check-prerequisites-gcp:
	@bash scripts/check-prerequisites.sh google

# Azure
create-cluster-azure: check-prerequisites-azure
	@$(MAKE) -C environments/azure create-cluster

delete-cluster-azure:
	@$(MAKE) -C environments/azure delete-cluster

check-prerequisites-azure:
	@bash scripts/check-prerequisites.sh azure
