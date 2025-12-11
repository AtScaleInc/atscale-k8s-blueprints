resource "google_container_cluster" "primary" {
  name                     = var.cluster_name
  location                 = var.region
  project                  = var.project_id
  min_master_version       = var.k8s_version != null ? var.k8s_version : null
  remove_default_node_pool = true
  initial_node_count       = var.initial_node_count
  network                  = var.network
  subnetwork               = var.subnetwork
  deletion_protection      = false

  # Private cluster configuration (only if private nodes are enabled)
  dynamic "private_cluster_config" {
    for_each = var.enable_private_nodes ? [1] : []
    content {
      enable_private_nodes    = true
      enable_private_endpoint = var.enable_private_endpoint
      master_ipv4_cidr_block  = var.master_ipv4_cidr_block
    }
  }

  # Master authorized networks (required when private endpoint is enabled)
  # When private endpoint is enabled, master authorized networks must also be enabled
  dynamic "master_authorized_networks_config" {
    for_each = var.enable_private_endpoint ? [1] : []
    content {
      dynamic "cidr_blocks" {
        for_each = var.master_authorized_networks
        content {
          cidr_block   = cidr_blocks.value.cidr_block
          display_name = cidr_blocks.value.display_name
        }
      }
    }
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_secondary_range_name
    services_secondary_range_name = var.services_secondary_range_name
  }


  network_policy {
    enabled = true
  }


  vertical_pod_autoscaling {
    enabled = true
  }


  # Workload identity (for IAM integration)
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Enable logging and monitoring
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }
  # Enable the Filestore CSI driver addon
  addons_config {
    gcp_filestore_csi_driver_config {
      enabled = true
    }
  }

  # Resource labels (GCP requires lowercase keys and values)
  resource_labels = {
    environment = lower(var.environment)
    managed_by  = "terraform"
  }

}


# Node Pool
resource "google_container_node_pool" "primary" {
  name       = var.node_pool_name
  location   = var.region
  cluster    = google_container_cluster.primary.name
  project    = var.project_id
  node_count = var.initial_node_count

  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    preemptible  = var.preemptible
    machine_type = var.machine_type

    # Service account for nodes
    service_account = google_service_account.gke_node.email

    # OAuth scopes
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      environment = lower(var.environment)
      managed_by  = "terraform"
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }

    tags = ["gke-node", "${var.cluster_name}"]

  }

  depends_on = [google_container_cluster.primary]
}

