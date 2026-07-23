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

variable "enable_private_cluster" {
  description = "Whether to enable private cluster (API server not publicly accessible)"
  type        = bool
  default     = false
}

variable "pod_cidr" {
  description = "CIDR used for pod IPs with Azure CNI overlay. Must not overlap the VNet address space."
  type        = string
  default     = "10.244.0.0/16"
}

variable "service_cidr" {
  description = "CIDR used for Kubernetes service IPs. Must not overlap the VNet address space or pod_cidr."
  type        = string
  default     = "10.0.0.0/16"
}

variable "dns_service_ip" {
  description = "IP address of the cluster DNS service. Must be inside service_cidr."
  type        = string
  default     = "10.0.0.10"
}

variable "enable_gateway_api" {
  description = "Enable the AKS-managed Gateway API installation. Required by the Application Gateway for Containers ALB controller add-on. PREVIEW: requires the ManagedGatewayAPIPreview feature to be registered on the subscription."
  type        = bool
  default     = true
}

variable "enable_application_load_balancer" {
  description = "Enable the Application Gateway for Containers ALB controller add-on, so the cluster can serve ingress via Gateway API. Also turns on workload identity, which the add-on requires. PREVIEW: requires the ApplicationLoadBalancerPreview feature and the Microsoft.NetworkFunction / Microsoft.ServiceNetworking providers to be registered on the subscription."
  type        = bool
  default     = true
}

variable "alb_addon_api_version" {
  description = "API version used to patch the applicationLoadBalancer add-on onto the cluster. Must be a version that exposes the property; while the add-on is in preview this has to be a -preview version."
  type        = string
  default     = "2025-09-02-preview"
}
