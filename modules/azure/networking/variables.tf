
variable "resource_group_name" {
  description = "The name of the Azure Resource Group to deploy resources into."
  type        = string
  default     = "atscale-aks-terraform-state"
}


variable "location" {
  description = "The Azure region to deploy resources into."
  type        = string
}


variable "vnet_name" {
  description = "The name of the Virtual Network (VNet)."
  type        = string
}


variable "address_space" {
  description = "The address space for the VNet."
  type        = list(string)
}


variable "nodes_subnet_cidr" {
  description = "List of address prefixes for public subnets."
  type        = string
}


variable "aks_subnet_cidr" {
  description = "List of address prefixes for AKS subnet."
  type        = string
}

variable "environment" {
  description = "The environment name (used for naming resources)."
  type        = string
}

variable "enable_postgresql" {
  type        = bool
  description = "The enable PostgreSQL of the PostgreSQL server"
}
