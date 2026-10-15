#!/bin/bash
#
# Check that a VM size is offered in a region and that the subscription has
# enough vCPU quota (for its VM family and in total) to run the node pool.
#
# AKS only reports insufficient quota (ErrCode_InsufficientVCPUQuota) several
# minutes into `terraform apply`, so check while the size is still being chosen.
#
# Exits 1 when the size is unavailable or the quota is short. When the lookup
# itself fails, it warns and exits 0 so it never blocks a deployment on its own.
#
# Usage: check-vm-quota.sh <region> <vm_size> <node_count> [subscription_id]

set -uo pipefail

REGION="${1:?region is required}"
VM_SIZE="${2:?vm_size is required}"
NODE_COUNT="${3:?node_count is required}"
SUBSCRIPTION_ID="${4:-$(az account show --query id -o tsv 2>/dev/null)}"

# The CLI's `az vm list-skus` takes about a minute; the REST call takes seconds.
SKU=$(az rest --method get \
  --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/providers/Microsoft.Compute/skus?api-version=2021-07-01&\$filter=location%20eq%20'${REGION}'" \
  --query "value[?resourceType=='virtualMachines' && name=='${VM_SIZE}'] | [0].[family, capabilities[?name=='vCPUs'].value | [0], length(restrictions)]" \
  -o tsv 2>/dev/null)
if [ $? -ne 0 ]; then
  echo "  [WARN] Could not look up $VM_SIZE in $REGION; skipping the quota check."
  exit 0
fi

# tsv prints each field of the list on its own line.
{ read -r FAMILY; read -r VCPUS; read -r RESTRICTIONS; } <<<"$SKU"
if [ -z "$FAMILY" ] || [ -z "$VCPUS" ]; then
  echo "  [ERROR] $VM_SIZE is not offered in $REGION (check the spelling, e.g. Standard_D16s_v6)."
  exit 1
fi
if [ "${RESTRICTIONS:-0}" != "0" ]; then
  echo "  [ERROR] $VM_SIZE is restricted for this subscription in $REGION."
  exit 1
fi

NEEDED=$((VCPUS * NODE_COUNT))
USAGE=$(az vm list-usage --location "$REGION" --subscription "$SUBSCRIPTION_ID" \
  --query "[].[name.value, currentValue, limit]" -o tsv 2>/dev/null)

free_for() {
  echo "$USAGE" | awk -F'\t' -v n="$1" 'tolower($1) == tolower(n) { print $3 - $2; exit }'
}

FAMILY_FREE=$(free_for "$FAMILY")
TOTAL_FREE=$(free_for "cores")
if [ -z "$FAMILY_FREE" ] || [ -z "$TOTAL_FREE" ]; then
  echo "  [WARN] Could not read vCPU quota for $FAMILY in $REGION; skipping the quota check."
  exit 0
fi

if [ "$FAMILY_FREE" -lt "$NEEDED" ] || [ "$TOTAL_FREE" -lt "$NEEDED" ]; then
  echo "  [ERROR] Not enough vCPU quota for $NODE_COUNT x $VM_SIZE in $REGION: needs $NEEDED vCPUs,"
  echo "          $FAMILY_FREE free in $FAMILY, $TOTAL_FREE free in total."
  echo "          Pick a size from a family with free quota (az vm list-usage --location $REGION -o table)"
  echo "          or request more: https://learn.microsoft.com/en-us/azure/quotas/view-quotas"
  exit 1
fi

echo "  [OK] vCPU quota: $NEEDED needed, $FAMILY_FREE free in $FAMILY ($REGION)."
