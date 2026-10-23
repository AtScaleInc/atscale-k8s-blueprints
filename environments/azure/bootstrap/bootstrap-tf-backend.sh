#!/bin/bash
#
# Create the Azure Storage backend for Terraform state, hardened by default:
#
#   - No anonymous blob access, TLS 1.2+, HTTPS only
#   - Shared key (account key) access disabled; Terraform authenticates with
#     Entra ID, so the deployer is granted Storage Blob Data Contributor
#   - Network access in one of three modes (TFSTATE_NETWORK_ACCESS):
#       public (default) - public endpoint reachable from any network; every
#                          request still needs an Entra ID identity with the
#                          data role, since keys and anonymous access are off
#       firewall         - public endpoint with a deny-by-default firewall
#                          that allows only ALLOWED_IP_RANGES (comma-separated
#                          IPs/CIDRs; defaults to the deployer's public IP)
#       private          - public network access disabled; reachable only
#                          through a private endpoint in
#                          PRIVATE_ENDPOINT_SUBNET_ID. Terraform must then
#                          run from a network that can reach it.
#
# Everything here goes through the Azure control plane (ARM), so it works even
# when the storage data plane is not reachable from where the script runs.

set -euo pipefail

# Accept parameters via environment variables
RESOURCE_GROUP_NAME="${RESOURCE_GROUP_NAME:-}"
LOCATION="${LOCATION:-}"
STORAGE_ACCOUNT_NAME="${STORAGE_ACCOUNT_NAME:-}"
CONTAINER_NAME="${CONTAINER_NAME:-tfstate}"
STATE_FILE_NAME="${STATE_FILE_NAME:-terraform.tfstate}"
SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-}"
TFSTATE_NETWORK_ACCESS="${TFSTATE_NETWORK_ACCESS:-public}"
ALLOWED_IP_RANGES="${ALLOWED_IP_RANGES:-}"
PRIVATE_ENDPOINT_SUBNET_ID="${PRIVATE_ENDPOINT_SUBNET_ID:-}"
PRIVATE_DNS_ZONE_ID="${PRIVATE_DNS_ZONE_ID:-}"

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

case "$TFSTATE_NETWORK_ACCESS" in
  public)
    ;;
  firewall)
    if [[ -z "$ALLOWED_IP_RANGES" ]]; then
      # Ask several services: behind a VPN or secure web gateway (Cloudflare
      # WARP, Zscaler, ...) each connection can leave from a different IP, and
      # allowing only one of them makes 'terraform init' fail with a 403 later.
      DETECTED_IPS=$(for URL in https://api.ipify.org https://ifconfig.me https://icanhazip.com https://checkip.amazonaws.com \
          https://api.ipify.org https://ifconfig.me; do
        curl -4 -fsS --max-time 10 "$URL" 2>/dev/null | tr -d '[:space:]'
        echo
      done | grep -E '^[0-9]+(\.[0-9]+){3}$' | sort -u)
      if [[ -z "$DETECTED_IPS" ]]; then
        echo "Error: could not detect your public IP. Set ALLOWED_IP_RANGES (comma-separated IPs/CIDRs)."
        exit 1
      fi
      ALLOWED_IP_RANGES=$(echo "$DETECTED_IPS" | paste -sd, -)
      echo "Allowing state access from your current public IP(s): $ALLOWED_IP_RANGES"
      if [[ $(echo "$DETECTED_IPS" | wc -l) -gt 1 ]]; then
        echo "WARNING: your public IP changes between connections (VPN or proxy such as"
        echo "         Cloudflare WARP or Zscaler), so Terraform may still be blocked by the"
        echo "         state firewall. Re-run with ALLOWED_IP_RANGES set to your organization's"
        echo "         egress range, disconnect the VPN/proxy while deploying, or use"
        echo "         TFSTATE_NETWORK_ACCESS=private."
      fi
    fi
    ;;
  private)
    if [[ -z "$PRIVATE_ENDPOINT_SUBNET_ID" ]]; then
      echo "Error: TFSTATE_NETWORK_ACCESS=private requires PRIVATE_ENDPOINT_SUBNET_ID"
      exit 1
    fi
    ;;
  *)
    echo "Error: TFSTATE_NETWORK_ACCESS must be 'public', 'firewall' or 'private'"
    exit 1
    ;;
esac

# Run every az command below against the chosen subscription, not just the CLI default.
az account set --subscription "$SUBSCRIPTION_ID"

# 1. Create resource group
az group create --name "$RESOURCE_GROUP_NAME" --location "$LOCATION"

# 2. Create storage account (hardened; firewall rules or private endpoint are added in step 5)
PUBLIC_NETWORK_ACCESS=$([[ "$TFSTATE_NETWORK_ACCESS" = "private" ]] && echo Disabled || echo Enabled)
DEFAULT_ACTION=$([[ "$TFSTATE_NETWORK_ACCESS" = "public" ]] && echo Allow || echo Deny)
az storage account create \
  --name "$STORAGE_ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --encryption-services blob \
  --https-only true \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --allow-shared-key-access false \
  --allow-cross-tenant-replication false \
  --public-network-access "$PUBLIC_NETWORK_ACCESS" \
  --default-action "$DEFAULT_ACTION" \
  --bypass AzureServices

STORAGE_ACCOUNT_ID=$(az storage account show --name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query id -o tsv)

# 3. Enable soft delete and versioning for blobs and containers
az storage account blob-service-properties update \
  --account-name "$STORAGE_ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --enable-delete-retention true \
  --delete-retention-days 7 \
  --enable-container-delete-retention true \
  --container-delete-retention-days 7 \
  --enable-versioning true

# 4. Create blob container through ARM (no account key or data-plane access needed)
az storage container-rm create \
  --name "$CONTAINER_NAME" \
  --storage-account "$STORAGE_ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --public-access off

# 5. Restrict network access (nothing to do in public mode)
if [[ "$TFSTATE_NETWORK_ACCESS" = "firewall" ]]; then
  IFS=',' read -ra RANGES <<< "$ALLOWED_IP_RANGES"
  for RANGE in "${RANGES[@]}"; do
    az storage account network-rule add \
      --account-name "$STORAGE_ACCOUNT_NAME" \
      --resource-group "$RESOURCE_GROUP_NAME" \
      --ip-address "$(echo "$RANGE" | xargs)" >/dev/null
  done
elif [[ "$TFSTATE_NETWORK_ACCESS" = "private" ]]; then
  PE_NAME="${STORAGE_ACCOUNT_NAME}-blob-pe"
  if ! az network private-endpoint show --name "$PE_NAME" --resource-group "$RESOURCE_GROUP_NAME" >/dev/null 2>&1; then
    az network private-endpoint create \
      --name "$PE_NAME" \
      --resource-group "$RESOURCE_GROUP_NAME" \
      --location "$LOCATION" \
      --subnet "$PRIVATE_ENDPOINT_SUBNET_ID" \
      --private-connection-resource-id "$STORAGE_ACCOUNT_ID" \
      --group-id blob \
      --connection-name "${STORAGE_ACCOUNT_NAME}-blob"
  fi
  # Register the endpoint in a privatelink.blob.core.windows.net zone so the
  # account name resolves to the private IP. Skip when your DNS is managed
  # centrally (e.g., Azure Policy creates the record in the hub zone).
  if [[ -n "$PRIVATE_DNS_ZONE_ID" ]]; then
    az network private-endpoint dns-zone-group create \
      --endpoint-name "$PE_NAME" \
      --resource-group "$RESOURCE_GROUP_NAME" \
      --name default \
      --private-dns-zone "$PRIVATE_DNS_ZONE_ID" \
      --zone-name blob
  fi
fi

# 6. Grant the deployer data-plane access. Shared key access is disabled, so
#    Terraform reads and writes state with its Entra ID identity.
if [[ "$(az account show --query user.type -o tsv)" = "servicePrincipal" ]]; then
  DEPLOYER_OBJECT_ID=$(az ad sp show --id "$(az account show --query user.name -o tsv)" --query id -o tsv)
  DEPLOYER_PRINCIPAL_TYPE=ServicePrincipal
else
  DEPLOYER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
  DEPLOYER_PRINCIPAL_TYPE=User
fi
az role assignment create \
  --assignee-object-id "$DEPLOYER_OBJECT_ID" \
  --assignee-principal-type "$DEPLOYER_PRINCIPAL_TYPE" \
  --role "Storage Blob Data Contributor" \
  --scope "$STORAGE_ACCOUNT_ID" >/dev/null

# Role assignments and firewall rules take a few minutes to propagate. Wait
# until the data plane answers so 'terraform init' doesn't fail with a 403.
# In private mode the endpoint may not be reachable from here, so don't wait.
if [[ "$TFSTATE_NETWORK_ACCESS" != "private" ]]; then
  echo "Waiting for state access to propagate (role assignment and firewall, up to 5 minutes)..."
  READY=false
  LAST_ERROR=""
  for i in $(seq 1 30); do
    if LAST_ERROR=$(az storage blob list --account-name "$STORAGE_ACCOUNT_NAME" --container-name "$CONTAINER_NAME" \
        --auth-mode login --num-results 1 -o none 2>&1); then
      READY=true
      break
    fi
    echo "  [$i/30] not ready yet: $(echo "$LAST_ERROR" | grep -oE 'AuthorizationPermissionMismatch|AuthorizationFailure|ErrorCode:[A-Za-z]+' | head -1)"
    sleep 10
  done
  if [[ "$READY" = "true" ]]; then
    echo "State access confirmed."
  else
    echo "WARNING: state access not confirmed after 5 minutes. Last error:"
    echo "$LAST_ERROR" | tail -3 | sed 's/^/           /'
    echo "         AuthorizationPermissionMismatch: the role assignment is still propagating;"
    echo "           wait a few minutes and continue."
    echo "         AuthorizationFailure (firewall mode): the firewall does not allow the IP Azure sees from you"
    echo "           (VPN/proxy). Re-run with ALLOWED_IP_RANGES=<your egress IP>, or add it with:"
    echo "           az storage account network-rule add -n $STORAGE_ACCOUNT_NAME -g $RESOURCE_GROUP_NAME --ip-address <ip>"
  fi
fi

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
  required_version = ">= 1.14.0"

  backend "azurerm" {
    resource_group_name  = "$RESOURCE_GROUP_NAME"
    storage_account_name = "$STORAGE_ACCOUNT_NAME"
    container_name       = "$CONTAINER_NAME"
    key                  = "$STATE_FILE_NAME"
    subscription_id      = "$SUBSCRIPTION_ID"
    use_azuread_auth     = true
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.46.0, < 5.0.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.9"
    }
    modtm = {
      source  = "azure/modtm"
      version = "~> 0.3"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0, < 4.0.0"
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
echo "  network access       = $TFSTATE_NETWORK_ACCESS"
echo "---------------------------------------------"
