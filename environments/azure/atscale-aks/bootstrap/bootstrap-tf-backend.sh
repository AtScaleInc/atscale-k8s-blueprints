#!/bin/bash

set -euo pipefail

# Variables - customize these!
RESOURCE_GROUP_NAME="[YOUR_RESOURCE_GROUP_NAME]"
LOCATION="[YOUR_REGION_NAME]"
STORAGE_ACCOUNT_NAME="[YOUR_STORAGE_ACCOUNT_NAME]"
CONTAINER_NAME="[YOUR_CONTAINER_NAME]"
STATE_FILE_NAME="[YOUR_STATE_FILE_NAME]"
SUBSCRIPTION_ID="[YOUR_SUBSCRIPTION_ID]"

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
echo "Use these values in your backend.tf:"
echo "resource_group_name  = \"$RESOURCE_GROUP_NAME\""
echo "storage_account_name = \"$STORAGE_ACCOUNT_NAME\""
echo "container_name       = \"$CONTAINER_NAME\""
echo "key                  = \"$STATE_FILE_NAME\""
echo "---------------------------------------------"

cat <<EOF > ../backend.tf
terraform {
  backend "azurerm" {
    resource_group_name  = "$RESOURCE_GROUP_NAME"
    storage_account_name = "$STORAGE_ACCOUNT_NAME"
    container_name       = "$CONTAINER_NAME"
    key                  = "$STATE_FILE_NAME"
  }
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.52.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "$SUBSCRIPTION_ID"
}
EOF
