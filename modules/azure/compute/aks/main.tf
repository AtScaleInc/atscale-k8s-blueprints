data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

data "azurerm_client_config" "current" {}

locals {
  cluster_name = "${var.cluster_name}${random_string.cluster_suffix.result}"
}

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

  name       = local.cluster_name
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

  # Workload identity is a hard prerequisite of the Application Gateway for
  # Containers ALB controller add-on, which authenticates its controller via a
  # federated credential on the `alb-controller-sa` service account.
  security_profile = {
    workload_identity = {
      enabled = var.enable_application_load_balancer
    }
  }

  # ingress_profile is deliberately not set here — both add-ons are applied by
  # the azapi patch below. See the comment on that resource.

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

# Ingress gateway add-ons: managed Gateway API + Application Gateway for
# Containers (ALB) controller.
#
# Both are applied here rather than through the AVM module because:
#
#   1. The module has no input for `ingressProfile.applicationLoadBalancer` at
#      all (checked against 0.6.7 and upstream main), so the ALB add-on cannot
#      be expressed through it.
#   2. The module does expose `ingress_profile.gateway_api`, but setting it
#      without also setting `web_app_routing` trips a bug in its own validation
#      (`coalesce(try(...web_app_routing...), "")` errors when web_app_routing
#      is null). Keeping both add-ons together avoids the workaround and keeps
#      one coherent ingress configuration.
#
# This does not fight the module: it filters null properties out of the request
# body, so with `ingress_profile` unset it never sends `ingressProfile` and
# will not revert this patch on subsequent applies.
#
# Pinned to a preview API version on purpose — the properties are gated behind
# preview feature flags and are not accepted by the GA API version the module
# uses. Move `alb_addon_api_version` forward once the add-ons go GA.
resource "azapi_update_resource" "ingress_profile" {
  count = var.enable_gateway_api || var.enable_application_load_balancer ? 1 : 0

  name      = local.cluster_name
  parent_id = data.azurerm_resource_group.this.id
  type      = "Microsoft.ContainerService/managedClusters@${var.alb_addon_api_version}"

  body = {
    properties = {
      ingressProfile = merge(
        var.enable_gateway_api ? { gatewayAPI = { installation = "Standard" } } : {},
        var.enable_application_load_balancer ? { applicationLoadBalancer = { enabled = true } } : {},
      )
    }
  }

  # Serialise against the cluster so the patch cannot race a module-driven
  # update, matching how the AVM module guards its own in-place updates.
  locks = [module.aks.resource_id]

  lifecycle {
    precondition {
      condition     = !var.enable_application_load_balancer || var.enable_gateway_api
      error_message = "enable_application_load_balancer requires enable_gateway_api: the ALB controller add-on only works with the AKS-managed Gateway API installation."
    }
  }
}
