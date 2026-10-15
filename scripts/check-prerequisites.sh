#!/bin/bash

set -euo pipefail

PROVIDER="${1:-}"
AWS_PROFILE="${2:-${AWS_PROFILE:-}}"
ERRORS=0

echo "============================================"
echo "  Checking Prerequisites"
echo "============================================"
echo ""

check_command() {
  local cmd="$1"
  local name="$2"
  local install_hint="$3"
  if command -v "$cmd" >/dev/null 2>&1; then
    local version
    if [ "$cmd" = "kubectl" ]; then
      version=$("$cmd" version --client 2>&1 | head -1 || true)
    elif [ "$cmd" = "az" ]; then
      version="Azure CLI $(az version 2>&1 | jq -r '.["azure-cli"]' 2>/dev/null || echo 'unknown')"
    elif [ "$cmd" = "kubelogin" ]; then
      version=$("$cmd" --version 2>&1 | grep "git hash" | sed 's/git hash: //' | cut -d'/' -f1 || echo 'unknown')
    else
      version=$("$cmd" --version 2>&1 | head -1 || true)
    fi
    echo "  [OK] $name ($version)"
  else
    echo "  [MISSING] $name - $install_hint"
    ERRORS=$((ERRORS + 1))
  fi
}

# Common tools
check_command "terraform" "Terraform (>= 1.14.0)" "https://www.terraform.io/downloads"
check_command "make" "Make" "Install via your package manager"
check_command "kubectl" "kubectl" "https://kubernetes.io/docs/tasks/tools/"
check_command "jq" "jq" "https://jqlang.github.io/jq/download/"
check_command "git" "git" "https://git-scm.com/downloads"

# Terraform version check
if command -v terraform >/dev/null 2>&1; then
  TF_VERSION=$(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || { terraform version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true; })
  TF_MAJOR=$(echo "$TF_VERSION" | cut -d. -f1)
  TF_MINOR=$(echo "$TF_VERSION" | cut -d. -f2)
  if [ "$TF_MAJOR" -lt 1 ] || ([ "$TF_MAJOR" -eq 1 ] && [ "$TF_MINOR" -lt 14 ]); then
    echo "  [WARNING] Terraform version $TF_VERSION is below 1.14.0"
    ERRORS=$((ERRORS + 1))
  fi
fi

echo ""

# Provider-specific checks
case "$PROVIDER" in
  aws)
    echo "AWS-specific checks:"
    check_command "aws" "AWS CLI" "https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    if command -v aws >/dev/null 2>&1; then
      AWS_PROFILE_OPTS=()
      PROFILE_LABEL="default"
      if [ -n "$AWS_PROFILE" ]; then
        AWS_PROFILE_OPTS=(--profile "$AWS_PROFILE")
        PROFILE_LABEL="$AWS_PROFILE"
      fi
      if aws sts get-caller-identity "${AWS_PROFILE_OPTS[@]+"${AWS_PROFILE_OPTS[@]}"}" >/dev/null 2>&1; then
        ACCOUNT=$(aws sts get-caller-identity "${AWS_PROFILE_OPTS[@]+"${AWS_PROFILE_OPTS[@]}"}" --query Account --output text 2>/dev/null)
        echo "  [OK] AWS credentials configured (profile: $PROFILE_LABEL, account: $ACCOUNT)"
      else
        echo "  [MISSING] AWS credentials not configured for profile '$PROFILE_LABEL' - run: aws configure --profile $PROFILE_LABEL"
        ERRORS=$((ERRORS + 1))
      fi
    fi
    ;;
  google|gcp)
    echo "Google Cloud-specific checks:"
    check_command "gcloud" "Google Cloud SDK" "https://cloud.google.com/sdk/docs/install"
    if command -v gcloud >/dev/null 2>&1; then
      ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null)
      if [ -n "$ACTIVE_ACCOUNT" ]; then
        echo "  [OK] gcloud authenticated as $ACTIVE_ACCOUNT"
      else
        echo "  [MISSING] gcloud not authenticated - run: gcloud auth login"
        ERRORS=$((ERRORS + 1))
      fi
      if gcloud auth application-default print-access-token >/dev/null 2>&1; then
        echo "  [OK] Application default credentials configured"
      else
        echo "  [MISSING] Application default credentials - run: gcloud auth application-default login"
        ERRORS=$((ERRORS + 1))
      fi
    fi
    ;;
  azure)
    echo "Azure-specific checks:"
    check_command "az" "Azure CLI" "https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    check_command "kubelogin" "kubelogin" "https://github.com/Azure/kubelogin"
    if command -v az >/dev/null 2>&1; then
      if az account show >/dev/null 2>&1; then
        SUBSCRIPTION=$(az account show --query name -o tsv 2>/dev/null)
        echo "  [OK] Azure authenticated (subscription: $SUBSCRIPTION)"

        # The deployer needs Contributor (to create the resources) plus the
        # right to create role assignments (Network Contributor for the cluster
        # identity, AKS RBAC Cluster Admin for the deployer). Only warn: the
        # roles may come from a custom role or PIM, which this cannot see.
        if [ "$(az account show --query user.type -o tsv 2>/dev/null)" = "user" ]; then
          ASSIGNEE=$(az ad signed-in-user show --query id -o tsv 2>/dev/null || true)
        else
          ASSIGNEE=$(az account show --query user.name -o tsv 2>/dev/null || true)
        fi
        ROLES=$(az role assignment list --assignee "$ASSIGNEE" --all --include-inherited --include-groups \
          --query "[].roleDefinitionName" -o tsv 2>/dev/null || true)
        if echo "$ROLES" | grep -qx "Owner" \
          || { echo "$ROLES" | grep -qx "Contributor" \
            && echo "$ROLES" | grep -Eqx "User Access Administrator|Role Based Access Control Administrator"; }; then
          echo "  [OK] Azure permissions (can create resources and role assignments)"
        else
          echo "  [WARN] Could not confirm Azure permissions. The deployer needs Contributor plus"
          echo "         Role Based Access Control Administrator (or Owner) on the subscription or"
          echo "         target resource groups - see 'Required permissions' in environments/azure/README.md."
        fi

        # A minimal cluster (the default), or one with enable_ingress_gateway =
        # false, never enables the preview add-ons, so their registrations are
        # only needed when terraform.tfvars sets minimal_cluster = false.
        TFVARS="$(dirname "$0")/../environments/azure/terraform.tfvars"
        if ! grep -Eq '^[[:space:]]*minimal_cluster[[:space:]]*=[[:space:]]*false' "$TFVARS" 2>/dev/null \
          || grep -Eq '^[[:space:]]*enable_ingress_gateway[[:space:]]*=[[:space:]]*false' "$TFVARS" 2>/dev/null; then
          echo "  [SKIP] Ingress gateway preview features (not needed for a minimal cluster)"
        else
          # The ingress gateway add-ons (Gateway API + Application Gateway for
          # Containers) are in preview. Without these registrations the cluster
          # create fails part-way through with an opaque ARM error, so check up
          # front and tell the user exactly what to run.
          for FEATURE in ManagedGatewayAPIPreview ApplicationLoadBalancerPreview; do
            STATE=$(az feature show --namespace Microsoft.ContainerService --name "$FEATURE" --query properties.state -o tsv 2>/dev/null)
            if [ "$STATE" = "Registered" ]; then
              echo "  [OK] Preview feature $FEATURE registered"
            else
              echo "  [MISSING] Preview feature $FEATURE is '${STATE:-NotRegistered}' - required for the ingress gateway add-ons."
              echo "            Run: az feature register --namespace Microsoft.ContainerService --name $FEATURE"
              echo "            Then wait for it to report Registered and run: az provider register --namespace Microsoft.ContainerService"
              echo "            Or set enable_ingress_gateway = false to deploy without them."
              ERRORS=$((ERRORS + 1))
            fi
          done

          for RP in Microsoft.NetworkFunction Microsoft.ServiceNetworking; do
            STATE=$(az provider show --namespace "$RP" --query registrationState -o tsv 2>/dev/null)
            if [ "$STATE" = "Registered" ]; then
              echo "  [OK] Resource provider $RP registered"
            else
              echo "  [MISSING] Resource provider $RP is '${STATE:-NotRegistered}' - required for the ingress gateway add-ons."
              echo "            Run: az provider register --namespace $RP"
              echo "            Or set enable_ingress_gateway = false to deploy without them."
              ERRORS=$((ERRORS + 1))
            fi
          done
        fi
      else
        echo "  [MISSING] Azure not authenticated - run: az login"
        ERRORS=$((ERRORS + 1))
      fi
    fi
    ;;
  *)
    echo "Usage: $0 <aws|google|azure> [aws-profile]"
    echo ""
    echo "Specify a cloud provider to check provider-specific tools."
    echo "For aws, optionally pass an AWS CLI profile name (or set AWS_PROFILE)."
    ;;
esac

echo ""
if [ "$ERRORS" -gt 0 ]; then
  echo "Found $ERRORS issue(s). Please resolve them before proceeding."
  exit 1
else
  echo "All prerequisites met!"
fi
