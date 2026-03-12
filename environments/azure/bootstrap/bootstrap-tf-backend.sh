#!/bin/bash

set -euo pipefail

# Accept parameters via environment variables
RESOURCE_GROUP_NAME="${RESOURCE_GROUP_NAME:-}"
LOCATION="${LOCATION:-}"
STORAGE_ACCOUNT_NAME="${STORAGE_ACCOUNT_NAME:-}"
CONTAINER_NAME="${CONTAINER_NAME:-tfstate}"
STATE_FILE_NAME="${STATE_FILE_NAME:-terraform.tfstate}"
SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-}"

# Validate inputs
if [[ -z "$RESOURCE_GROUP_NAME" ]]; then
  echo "Error: RESOURCE_GROUP_NAME must be set"
  exit 1
fi

if [[ -z "$LOCATION" ]]; then
  echo "Error: LOCATION must be set (e.g., eastus, westus3)"
  exit 1
fi

if [[ -z "$STORAGE_ACCOUNT_NAME" ]]; then
  echo "Error: STORAGE_ACCOUNT_NAME must be set (lowercase, alphanumeric only)"
  exit 1
fi

if [[ -z "$SUBSCRIPTION_ID" ]]; then
  echo "Error: SUBSCRIPTION_ID must be set"
  exit 1
fi

# 1. Create resource group
az group create --name $RESOURCE_GROUP_NAME --location $LOCATION

# 2. Create storage account (Standard, with blob encryption)
az storage account create \
  --name $STORAGE_ACCOUNT_NAME \
  --resource-group $RESOURCE_GROUP_NAME \
  --location $LOCATION \
  --sku Standard_LRS \
  --encryption-services blob

# 3. Enable soft delete for blobs (recommended)
az storage account blob-service-properties update \
  --account-name $STORAGE_ACCOUNT_NAME \
  --resource-group $RESOURCE_GROUP_NAME \
  --enable-delete-retention true \
  --delete-retention-days 7

# 4. Enable versioning (recommended)
az storage account blob-service-properties update \
  --account-name $STORAGE_ACCOUNT_NAME \
  --resource-group $RESOURCE_GROUP_NAME \
  --enable-versioning true

# 5. Get storage account key
ACCOUNT_KEY=$(az storage account keys list --resource-group $RESOURCE_GROUP_NAME --account-name $STORAGE_ACCOUNT_NAME --query '[0].value' -o tsv)

# 6. Create blob container
az storage container create \
  --name $CONTAINER_NAME \
  --account-name $STORAGE_ACCOUNT_NAME \
  --account-key $ACCOUNT_KEY

echo "---------------------------------------------"
echo "Backend configuration created successfully!"
echo "---------------------------------------------"
echo "Generating backend.tf file..."

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_FILE="${SCRIPT_DIR}/../backend.tf"

cat <<EOF > "$BACKEND_FILE"
# Terraform Backend
################################################################################

terraform {
  required_version = ">= 1.11.0"

  backend "azurerm" {
    resource_group_name  = "$RESOURCE_GROUP_NAME"
    storage_account_name = "$STORAGE_ACCOUNT_NAME"
    container_name       = "$CONTAINER_NAME"
    key                  = "$STATE_FILE_NAME"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "$SUBSCRIPTION_ID"
}
EOF

echo "backend.tf file generated successfully at: $BACKEND_FILE"
echo "---------------------------------------------"
echo "Configuration details:"
echo "  resource_group_name  = \"$RESOURCE_GROUP_NAME\""
echo "  storage_account_name = \"$STORAGE_ACCOUNT_NAME\""
echo "  container_name       = \"$CONTAINER_NAME\""
echo "  key                  = \"$STATE_FILE_NAME\""
echo "---------------------------------------------"
