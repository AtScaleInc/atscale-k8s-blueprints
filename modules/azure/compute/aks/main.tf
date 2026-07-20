data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

data "azurerm_client_config" "current" {}

# The previous module appended a random suffix to the cluster name via
# `cluster_name_random_suffix`. The AVM module has no equivalent, so we
# generate the suffix ourselves to keep cluster naming behaviour unchanged.
resource "random_string" "cluster_suffix" {
  length  = 4
  lower   = true
  numeric = true
  special = false
  upper   = false
}

# The AVM resource module does not create a Log Analytics workspace (the
# retired Azure/aks module did). We create it here so Container Insights
# keeps working and the module's public interface stays the same.
resource "azurerm_log_analytics_workspace" "this" {
  name                = var.cluster_log_analytics_workspace_name
  location            = var.location
  resource_group_name = data.azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

module "aks" {
  source  = "Azure/avm-res-containerservice-managedcluster/azurerm"
  version = "0.6.7"

  name       = "${var.cluster_name}${random_string.cluster_suffix.result}"
  location   = var.location
  parent_id  = data.azurerm_resource_group.this.id
  dns_prefix = var.prefix

  kubernetes_version  = var.kubernetes_version
  node_resource_group = var.node_resource_group_name
  enable_rbac         = true
  enable_telemetry    = false

  managed_identities = {
    system_assigned = true
  }

  aad_profile = {
    managed                = true
    enable_azure_rbac      = true
    tenant_id              = data.azurerm_client_config.current.tenant_id
    admin_group_object_ids = var.aad_admin_group_object_ids
  }

  oidc_issuer_profile = {
    enabled = true
  }

  api_server_access_profile = {
    enable_private_cluster = var.enable_private_cluster
  }

  # The retired module left this implicit, which resolved to kubenet.
  # Azure is retiring kubenet, and the AVM module requires an explicit
  # network profile, so we pin Azure CNI overlay.
  network_profile = {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
    pod_cidr            = var.pod_cidr
    service_cidr        = var.service_cidr
    dns_service_ip      = var.dns_service_ip
  }

  default_agent_pool = {
    name           = "workers"
    count_of       = var.default_node_pool_node_count
    vm_size        = var.default_node_pool_vm_size
    vnet_subnet_id = var.aks_subnet_id

    # drain_timeout_in_minutes is intentionally unset: the retired module
    # allowed 0, but the AKS API minimum is 1 and the AVM module validates it.
    # Unset falls back to the AKS default of 30 minutes.
    upgrade_settings = {
      node_soak_duration_in_minutes = 0
      max_surge                     = "10%"
    }
  }

  addon_profile_oms_agent = {
    enabled = true
    config = {
      log_analytics_workspace_resource_id = azurerm_log_analytics_workspace.this.id
      use_aad_auth                        = true
    }
  }

  sku = {
    name = "Base"
    tier = "Free"
  }
}

resource "azurerm_role_assignment" "aks_network_contributor_on_vnet" {
  scope                = var.aks_subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = module.aks.identity_principal_id
}
