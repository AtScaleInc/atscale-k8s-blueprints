#!/bin/bash

set -euo pipefail

PROVIDER="${1:-}"
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
      version=$("$cmd" version --client 2>&1 | head -1)
    elif [ "$cmd" = "az" ]; then
      version="Azure CLI $(az version 2>&1 | jq -r '.["azure-cli"]' 2>/dev/null || echo 'unknown')"
    elif [ "$cmd" = "kubelogin" ]; then
      version=$("$cmd" --version 2>&1 | grep "git hash" | sed 's/git hash: //' | cut -d'/' -f1 || echo 'unknown')
    else
      version=$("$cmd" --version 2>&1 | head -1)
    fi
    echo "  [OK] $name ($version)"
  else
    echo "  [MISSING] $name - $install_hint"
    ERRORS=$((ERRORS + 1))
  fi
}

# Common tools
check_command "terraform" "Terraform (>= 1.11.0)" "https://www.terraform.io/downloads"
check_command "make" "Make" "Install via your package manager"
check_command "kubectl" "kubectl" "https://kubernetes.io/docs/tasks/tools/"
check_command "jq" "jq" "https://jqlang.github.io/jq/download/"
check_command "git" "git" "https://git-scm.com/downloads"

# Terraform version check
if command -v terraform >/dev/null 2>&1; then
  TF_VERSION=$(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || terraform version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  TF_MAJOR=$(echo "$TF_VERSION" | cut -d. -f1)
  TF_MINOR=$(echo "$TF_VERSION" | cut -d. -f2)
  if [ "$TF_MAJOR" -lt 1 ] || ([ "$TF_MAJOR" -eq 1 ] && [ "$TF_MINOR" -lt 11 ]); then
    echo "  [WARNING] Terraform version $TF_VERSION is below 1.11.0"
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
      if aws sts get-caller-identity >/dev/null 2>&1; then
        ACCOUNT=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
        echo "  [OK] AWS credentials configured (account: $ACCOUNT)"
      else
        echo "  [MISSING] AWS credentials not configured - run: aws configure"
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
      else
        echo "  [MISSING] Azure not authenticated - run: az login"
        ERRORS=$((ERRORS + 1))
      fi
    fi
    ;;
  *)
    echo "Usage: $0 <aws|google|azure>"
    echo ""
    echo "Specify a cloud provider to check provider-specific tools."
    ;;
esac

echo ""
if [ "$ERRORS" -gt 0 ]; then
  echo "Found $ERRORS issue(s). Please resolve them before proceeding."
  exit 1
else
  echo "All prerequisites met!"
fi
