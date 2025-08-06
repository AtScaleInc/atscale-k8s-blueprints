# Terraform Backend
################################################################################

terraform {
  required_version = ">= 1.11.0"

  backend "s3" {
    bucket       = "YOUR-BUCKET-NAME" # Replace with your bucket name to store the state file
    key          = "tf-state/terraform.tfstate"
    region       = "YOUR-REGION"  # Replace with your region
    profile      = "YOUR-PROFILE" # Replace with your profile
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
    null = {
      source  = "hashicorp/null"
      version = "3.2.4"
    }
  }
}

provider "aws" {
  region  = local.region
  profile = "YOUR-PROFILE" # Replace with your profile or you can delete this line if you are using the default profile

  default_tags {
    tags = {
      Environment = "${local.environment}"
      ManagedBy   = "terraform"
      Project     = "${local.environment}-tf"
    }
  }
}

provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    command     = "aws"
  }
}
