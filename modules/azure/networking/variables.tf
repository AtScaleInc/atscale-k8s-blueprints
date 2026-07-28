
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

variable "enable_ingress_gateway" {
  type        = bool
  description = "Create the delegated subnet for the Application Gateway for Containers association. Set when the ingress gateway add-ons are enabled."
  default     = false
}

variable "alb_subnet_cidr" {
  type        = string
  description = "Address prefix for the Application Gateway for Containers association subnet. Must be a /24 or larger and not overlap other subnets. Only used when enable_ingress_gateway is true."
  default     = null
}
