data "azurerm_kubernetes_cluster" "this" {
  name                = module.aks.aks_name
  resource_group_name = var.resource_group_name
}
