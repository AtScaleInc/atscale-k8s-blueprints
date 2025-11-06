# Terraform Backend
################################################################################

terraform {
  required_version = ">= 1.11.0"

  backend "gcs" {
    bucket = "[YOUR_BUCKET_NAME]"       # Replace with your GCS bucket name to store the state file
    prefix = "[YOUR_STATE_FILE_PREFIX]" # Replace with your state file prefix
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

provider "google" {
  project = local.project_id
  region  = local.region

  default_labels = {
    environment = lower(local.environment)
    managed_by  = "terraform"
    project     = "${lower(local.environment)}-tf"
  }
}

provider "kubectl" {
  host                   = module.gke.cluster_endpoint
  cluster_ca_certificate = base64decode(module.gke.cluster_ca_certificate)
  token                  = data.google_client_config.default.access_token
  load_config_file       = false
}

