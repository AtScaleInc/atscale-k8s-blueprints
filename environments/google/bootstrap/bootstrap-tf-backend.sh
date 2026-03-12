#!/bin/bash

set -euo pipefail

# Accept parameters via environment variables
PROJECT_ID="${PROJECT_ID:-}"
BUCKET_NAME="${BUCKET_NAME:-}"
LOCATION="${LOCATION:-}"
STATE_FILE_PREFIX="${STATE_FILE_PREFIX:-terraform/state}"

# Validate inputs
if [[ -z "$PROJECT_ID" ]]; then
  echo "Error: PROJECT_ID must be set"
  exit 1
fi

if [[ -z "$BUCKET_NAME" ]]; then
  echo "Error: BUCKET_NAME must be set"
  exit 1
fi

if [[ -z "$LOCATION" ]]; then
  echo "Error: LOCATION must be set (e.g., us-central1, us-east1)"
  exit 1
fi

# Set the project
gcloud config set project $PROJECT_ID

# 1. Create GCS bucket (if it doesn't exist)
if gsutil ls -b gs://$BUCKET_NAME >/dev/null 2>&1; then
  echo "Bucket $BUCKET_NAME already exists, skipping creation..."
else
  echo "Creating GCS bucket $BUCKET_NAME..."
  gsutil mb -p $PROJECT_ID -l $LOCATION gs://$BUCKET_NAME
fi

# 2. Enable versioning (recommended for state files)
echo "Enabling versioning on bucket..."
gsutil versioning set on gs://$BUCKET_NAME

# 3. Enable uniform bucket-level access (recommended)
echo "Enabling uniform bucket-level access..."
gsutil uniformbucketlevelaccess set on gs://$BUCKET_NAME

# 4. Set lifecycle policy to retain noncurrent versions (keep last 10 versions)
echo "Setting lifecycle policy..."
cat <<EOF > /tmp/lifecycle.json
{
  "rule": [
    {
      "action": {
        "type": "Delete"
      },
      "condition": {
        "numNewerVersions": 10
      }
    }
  ]
}
EOF
gsutil lifecycle set /tmp/lifecycle.json gs://$BUCKET_NAME
rm /tmp/lifecycle.json

# 5. Set bucket encryption (default encryption is enabled by default, but we can be explicit)
echo "Bucket encryption is enabled by default in GCS"

# 6. Set bucket labels
echo "Setting bucket labels..."
gsutil label ch -l "managed-by:terraform" gs://$BUCKET_NAME
gsutil label ch -l "purpose:terraform-state" gs://$BUCKET_NAME

echo "---------------------------------------------"
echo "Backend configuration created successfully!"
echo "---------------------------------------------"
echo "Generating backend.tf file..."

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Go up one level to the environment directory
BACKEND_FILE="${SCRIPT_DIR}/../backend.tf"

# Generate the backend.tf file
cat <<EOF > "$BACKEND_FILE"
# Terraform Backend
################################################################################

terraform {
  required_version = ">= 1.11.0"

  backend "gcs" {
    bucket = "$BUCKET_NAME"
    prefix = "$STATE_FILE_PREFIX"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "7.10.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.19.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.4"
    }
  }
}

data "google_client_config" "default" {}

provider "google" {
  project = var.project_id
  region  = var.region

  default_labels = {
    environment = lower(var.environment)
    managed_by  = "terraform"
    project     = "\${lower(var.environment)}-gke-tf"
  }
}

provider "kubectl" {
  host                   = module.gke.cluster_endpoint
  cluster_ca_certificate = base64decode(module.gke.cluster_ca_certificate)
  token                  = data.google_client_config.default.access_token
  load_config_file       = false
}

EOF

echo "backend.tf file generated successfully at: $BACKEND_FILE"
echo "---------------------------------------------"
echo "Configuration details:"
echo "  bucket = \"$BUCKET_NAME\""
echo "  prefix = \"$STATE_FILE_PREFIX\""
echo "---------------------------------------------"
