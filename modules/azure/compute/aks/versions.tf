terraform {
  required_version = ">= 1.11.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.46.0, < 5.0.0"
    }
    # Must be declared explicitly: without a source, Terraform resolves the
    # azapi_* resources below to the non-existent hashicorp/azapi provider.
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.9"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0, < 4.0.0"
    }
  }
}
