############################################################################
# General Variables
############################################################################

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.environment)) && length(var.environment) >= 2
    error_message = "Environment must be lowercase alphanumeric with hyphens, at least 2 characters."
  }
}

variable "vpc_cidr" {
  description = "VNet address space CIDR (e.g., 10.85.0.0/22). Split into four equal subnets. Must be /22 or larger when the ingress gateway is enabled (its subnet needs a /24); /26 is enough otherwise (e.g., minimal_cluster = true)."
  type        = string
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Must be a valid CIDR block (e.g., 10.85.0.0/22)."
  }
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && var.vpc_cidr == "${cidrhost(var.vpc_cidr, 0)}/${split("/", var.vpc_cidr)[1]}"
    error_message = "VNet CIDR has host bits set — it is not a valid network address. Use the network address (e.g., 10.85.0.0/22 instead of 10.85.3.0/22)."
  }
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && tonumber(split("/", var.vpc_cidr)[1]) <= 26
    error_message = "VNet CIDR must be /26 or larger. Each subnet is a quarter of the VNet, and anything smaller than a /28 leaves too few addresses for a node, an upgrade surge node and the load balancer front ends."
  }
  validation {
    condition     = var.minimal_cluster || !var.enable_ingress_gateway || (can(cidrhost(var.vpc_cidr, 0)) && tonumber(split("/", var.vpc_cidr)[1]) <= 22)
    error_message = "With enable_ingress_gateway = true the VNet CIDR must be /22 or larger: the Application Gateway for Containers subnet is a quarter of the VNet and must be at least a /24. Use a /22, set enable_ingress_gateway = false, or set minimal_cluster = true."
  }
}

variable "region" {
  description = "Azure region (e.g., eastus, westus3)"
  type        = string
  validation {
    condition     = length(var.region) > 0
    error_message = "Region cannot be empty."
  }
}

variable "resource_group_name" {
  description = "Azure resource group name"
  type        = string
  validation {
    condition     = length(var.resource_group_name) > 0
    error_message = "Resource group name cannot be empty."
  }
}

############################################################################
# AKS Variables
############################################################################

variable "aks_version" {
  description = "Kubernetes version for AKS"
  type        = string
  default     = "1.35"
}

variable "minimal_cluster" {
  description = "Deploy a minimal cluster (1 node, no ingress gateway add-ons) for dev/test and POCs. Overrides aks_node_count, enable_ingress_gateway and create_default_alb. Requires at least Standard_D16s_v5 (16 vCPU / 64 GB) — all AtScale components must fit on a single node."
  type        = bool
  default     = true
}

variable "aks_node_count" {
  description = "Number of nodes in the AKS default node pool"
  type        = number
  default     = 3
}

variable "aks_node_size" {
  description = "VM size for AKS nodes (e.g., Standard_D8s_v5)"
  type        = string
  default     = "Standard_D8s_v5"
}

variable "aad_admin_group_object_id" {
  description = "Optional Azure AD (Entra ID) group whose members become cluster admins. Leave empty to grant access only to the deployer (see grant_deployer_cluster_admin)."
  type        = string
  default     = ""
}

variable "grant_deployer_cluster_admin" {
  description = "Grant the identity running Terraform the Azure Kubernetes Service RBAC Cluster Admin role on the cluster, so it can run kubectl and install AtScale."
  type        = bool
  default     = true
}

variable "public_api_server" {
  description = "Whether the cluster API server is publicly accessible. Set to false for a fully private cluster (requires VPN or bastion to run kubectl)."
  type        = bool
  default     = true
}

variable "authorized_network_cidr" {
  description = "CIDR block allowed to access the private API server. Used when public_api_server is false."
  type        = string
  default     = ""
}

variable "enable_ingress_gateway" {
  description = "Provision the cluster ready to serve ingress via Gateway API, by enabling the AKS-managed Gateway API installation and the Application Gateway for Containers (ALB) controller add-on. Both are in PREVIEW and require subscription-level feature registration - see the README prerequisites before enabling."
  type        = bool
  default     = true
}

variable "create_default_alb" {
  description = "After the cluster is created, apply a default ApplicationLoadBalancer resource so an Application Gateway for Containers is provisioned out of the box. Only takes effect via 'make create-cluster-azure' and when enable_ingress_gateway is true. Off by default because it provisions a billable Azure resource on every cluster; leave false and create the resource yourself if you prefer to control its name/namespace."
  type        = bool
  default     = false

  validation {
    condition     = !var.create_default_alb || var.enable_ingress_gateway
    error_message = "create_default_alb requires enable_ingress_gateway = true: the default ALB needs the ingress gateway add-ons and the association subnet they create."
  }
}

############################################################################
# Cluster Networking Variables
# Pod and service ranges are not VNet address space, but they must not overlap
# the VNet, peered VNets, ExpressRoute/VPN or on-prem ranges reachable from
# the cluster, nor the AKS-reserved ranges 169.254.0.0/16, 192.0.2.0/24,
# 172.30.0.0/16 and 172.31.0.0/16.
############################################################################

variable "pod_cidr" {
  description = "Azure CNI Overlay pod range. Each node takes a fixed /24 from it (a /20 covers 16 nodes). Use RFC 1918 or RFC 6598 (100.64.0.0/10) space."
  type        = string
  default     = "10.244.0.0/16"
  validation {
    condition     = can(cidrhost(var.pod_cidr, 0)) && tonumber(split("/", var.pod_cidr)[1]) <= 24
    error_message = "pod_cidr must be a valid CIDR block of /24 or larger (each node takes a /24)."
  }
}

variable "service_cidr" {
  description = "Kubernetes service range. Must be smaller than a /12 and must not overlap pod_cidr or the VNet."
  type        = string
  default     = "10.0.0.0/16"
  validation {
    condition     = can(cidrhost(var.service_cidr, 0)) && tonumber(split("/", var.service_cidr)[1]) > 12
    error_message = "service_cidr must be a valid CIDR block smaller than a /12 (e.g., 10.0.0.0/16 or 192.168.100.0/24)."
  }
}

variable "dns_service_ip" {
  description = "Cluster DNS service IP. Must be inside service_cidr and not its first address. Defaults to the 10th address of service_cidr."
  type        = string
  default     = null
  validation {
    condition     = var.dns_service_ip == null || can(cidrhost("${var.dns_service_ip}/32", 0))
    error_message = "dns_service_ip must be a valid IPv4 address."
  }
}

variable "outbound_type" {
  description = "Cluster egress: loadBalancer (AKS-managed public IP) or userDefinedRouting (egress through your firewall/NVA; requires route_table_id)."
  type        = string
  default     = "loadBalancer"
  validation {
    condition     = contains(["loadBalancer", "userDefinedRouting"], var.outbound_type)
    error_message = "outbound_type must be loadBalancer or userDefinedRouting."
  }
}

variable "route_table_id" {
  description = "ID of an existing route table with a 0.0.0.0/0 route to your firewall/NVA, associated with the AKS node subnet. Required when outbound_type = userDefinedRouting."
  type        = string
  default     = null
  validation {
    condition     = var.outbound_type != "userDefinedRouting" || var.route_table_id != null
    error_message = "outbound_type = userDefinedRouting requires route_table_id: AKS validates that the node subnet has a 0.0.0.0/0 route to a gateway or NVA."
  }
}

############################################################################
# Database Variables
############################################################################

variable "enable_postgresql" {
  description = "Whether to create an Azure PostgreSQL Flexible Server instance"
  type        = bool
  default     = false
}

variable "postgresql_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "16"
}

variable "postgresql_sku_name" {
  description = "PostgreSQL SKU name (e.g., GP_Standard_D4ads_v5)"
  type        = string
  default     = "GP_Standard_D4ads_v5"
}

variable "postgresql_storage_mb" {
  description = "PostgreSQL storage in MB"
  type        = number
  default     = 65536
}

variable "postgresql_backup_retention_days" {
  description = "PostgreSQL backup retention days (minimum 7)"
  type        = number
  default     = 7
  validation {
    condition     = var.postgresql_backup_retention_days >= 7
    error_message = "Backup retention days must be at least 7."
  }
}

variable "postgresql_geo_redundant_backup_enabled" {
  description = "Whether to enable geo-redundant backups"
  type        = bool
  default     = false
}

variable "postgresql_admin_username" {
  description = "PostgreSQL admin username"
  type        = string
  default     = "postgres"
}
