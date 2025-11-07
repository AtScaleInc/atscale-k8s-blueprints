module "aks" {
  source  = "Azure/aks/azurerm"
  version = "11.0.0"

  location                             = var.location
  prefix                               = var.prefix
  private_cluster_enabled              = false
  rbac_aad_azure_rbac_enabled          = true # Enable RBAC for AAD
  role_based_access_control_enabled    = true # Enable RBAC for AKS
  rbac_aad_admin_group_object_ids      = var.aad_admin_group_object_ids
  oidc_issuer_enabled                  = true
  resource_group_name                  = var.resource_group_name
  cluster_name                         = var.cluster_name
  cluster_name_random_suffix           = true
  node_resource_group                  = var.node_resource_group_name
  kubernetes_version                   = var.kubernetes_version
  cluster_log_analytics_workspace_name = var.cluster_log_analytics_workspace_name
  vnet_subnet                          = { id = var.aks_subnet_id }

  node_pools = {
    workers = {
      name                        = "workers"
      node_count                  = var.default_node_pool_node_count
      vm_size                     = var.default_node_pool_vm_size
      temporary_name_for_rotation = "tmpnodepool1"
      vnet_subnet                 = { id = var.aks_subnet_id }
      upgrade_settings = {
        drain_timeout_in_minutes      = 0
        node_soak_duration_in_minutes = 0
        max_surge                     = "10%"
      }
    }
  }

}


resource "azurerm_role_assignment" "aks_network_contributor_on_vnet" {
  scope                = var.aks_subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = data.azurerm_kubernetes_cluster.this.identity[0].principal_id
}
