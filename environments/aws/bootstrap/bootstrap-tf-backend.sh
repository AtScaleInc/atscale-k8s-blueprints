#!/bin/bash

set -euo pipefail

# Accept parameters via environment variables
BUCKET_NAME="${BUCKET_NAME:-}"
REGION="${REGION:-}"
STATE_FILE_KEY="${STATE_FILE_KEY:-}"
AWS_PROFILE="${AWS_PROFILE:-default}"

# Validate inputs
if [[ -z "$BUCKET_NAME" ]]; then
  echo "Error: BUCKET_NAME must be set"
  exit 1
fi

if [[ -z "$REGION" ]]; then
  echo "Error: REGION must be set (e.g., us-east-1, us-west-2)"
  exit 1
fi

if [[ -z "$STATE_FILE_KEY" ]]; then
  echo "Error: STATE_FILE_KEY must be set (e.g., tf-state/terraform.tfstate)"
  exit 1
fi

# Set AWS profile
export AWS_PROFILE=$AWS_PROFILE

# 1. Create S3 bucket (if it doesn't exist)
if aws s3 ls "s3://$BUCKET_NAME" --region $REGION >/dev/null 2>&1; then
  echo "Bucket $BUCKET_NAME already exists, skipping creation..."
else
  echo "Creating S3 bucket $BUCKET_NAME in region $REGION..."
  if [[ "$REGION" == "us-east-1" ]]; then
    aws s3api create-bucket \
      --bucket $BUCKET_NAME \
      --region $REGION
  else
    aws s3api create-bucket \
      --bucket $BUCKET_NAME \
      --region $REGION \
      --create-bucket-configuration LocationConstraint=$REGION
  fi
fi

# 2. Enable versioning (recommended for state files)
echo "Enabling versioning on bucket..."
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled \
  --region $REGION

# 3. Enable server-side encryption
echo "Enabling server-side encryption..."
aws s3api put-bucket-encryption \
  --bucket $BUCKET_NAME \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        },
        "BucketKeyEnabled": true
      }
    ]
  }' \
  --region $REGION

# 4. Block public access
echo "Blocking public access..."
aws s3api put-public-access-block \
  --bucket $BUCKET_NAME \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
  --region $REGION

# 5. Set bucket tags
echo "Setting bucket tags..."
aws s3api put-bucket-tagging \
  --bucket $BUCKET_NAME \
  --tagging 'TagSet=[{Key=ManagedBy,Value=terraform},{Key=Purpose,Value=terraform-state}]' \
  --region $REGION

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

  backend "s3" {
    bucket       = "$BUCKET_NAME"
    key          = "$STATE_FILE_KEY"
    region       = "$REGION"
    profile      = "$AWS_PROFILE"
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.19.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.4"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = "$AWS_PROFILE"

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "terraform"
      Project     = "\${var.environment}-tf"
    }
  }
}

provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.region, "--profile", "$AWS_PROFILE"]
    command     = "aws"
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.region, "--profile", "$AWS_PROFILE"]
      command     = "aws"
    }
  }
}

EOF

echo "backend.tf file generated successfully at: $BACKEND_FILE"
echo "---------------------------------------------"
echo "Configuration details:"
echo "  bucket  = \"$BUCKET_NAME\""
echo "  key     = \"$STATE_FILE_KEY\""
echo "  region  = \"$REGION\""
echo "  profile = \"$AWS_PROFILE\""
echo "---------------------------------------------"
