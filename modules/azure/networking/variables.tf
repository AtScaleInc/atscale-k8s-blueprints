
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

variable "route_table_id" {
  type        = string
  description = "ID of an existing route table to associate with the AKS subnet (for outbound_type = userDefinedRouting). Null leaves the subnet without a route table."
  default     = null
}

variable "existing_vnet_name" {
  type        = string
  description = "Name of an existing VNet to deploy the subnets into instead of creating one. Null creates a new VNet."
  default     = null
}

variable "existing_vnet_resource_group_name" {
  type        = string
  description = "Resource group of the existing VNet. Defaults to resource_group_name. Only used with existing_vnet_name."
  default     = null
}

variable "atscale_ports" {
  type        = list(string)
  description = "TCP ports AtScale serves on, allowed inbound on the AKS subnet NSG."
  default     = ["80", "443", "15432"]
}

variable "atscale_allowed_source_prefixes" {
  type        = list(string)
  description = "CIDRs or service tags allowed to reach the AtScale ports. One NSG rule is created per entry."
  default     = ["VirtualNetwork"]
}
