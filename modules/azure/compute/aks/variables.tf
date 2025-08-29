variable "location" {
  type        = string
  description = "The location of the AKS cluster"
}

variable "resource_group_name" {
  type        = string
  description = "The resource group of the AKS cluster"
}

variable "cluster_name" {
  type        = string
  description = "The name of the AKS cluster"
}

variable "node_resource_group_name" {
  type        = string
  description = "The node resource group of the AKS cluster"
}

variable "kubernetes_version" {
  type        = string
  description = "The version of Kubernetes to use for the AKS cluster"
}

variable "cluster_log_analytics_workspace_name" {
  type        = string
  description = "The name of the log analytics workspace for the AKS cluster"
}

variable "prefix" {
  type        = string
  description = "The prefix for the AKS cluster"
}

variable "aad_admin_group_object_ids" {
  type        = list(string)
  description = "List of Azure AD Group Object IDs that will be cluster admins for AKS."
}

variable "default_node_pool_node_count" {
  type        = number
  description = "The number of nodes in the default node pool"
}

variable "default_node_pool_vm_size" {
  type        = string
  description = "The size of the nodes in the default node pool"
}

variable "environment" {
  type        = string
  description = "The environment name (used for naming and tagging resources)."
}

variable "aks_subnet_id" {
  type        = string
  description = "The ID of the AKS subnet"
}
