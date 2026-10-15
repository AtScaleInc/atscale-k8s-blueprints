#!/bin/bash
#
# Wait until the current kubeconfig identity has cluster-admin rights.
#
# Terraform grants the deployer the "Azure Kubernetes Service RBAC Cluster
# Admin" role on the cluster, but Azure RBAC assignments take a minute or two
# to propagate to the AKS API server. Without this wait, the first kubectl
# call after `terraform apply` can fail with Forbidden.
#
# Usage: wait-for-cluster-admin.sh [timeout_seconds]

set -euo pipefail

TIMEOUT="${1:-600}"
INTERVAL=15
ELAPSED=0

echo "Waiting for cluster-admin access (Azure RBAC role propagation)..."
until [ "$(kubectl auth can-i '*' '*' --all-namespaces 2>/dev/null)" = "yes" ]; do
  if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
    echo "ERROR: no cluster-admin access after ${TIMEOUT}s."
    echo "       Check that your identity has the 'Azure Kubernetes Service RBAC Cluster Admin'"
    echo "       role on the cluster, or is a member of the configured AAD admin group."
    exit 1
  fi
  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
done
echo "Cluster-admin access confirmed."
