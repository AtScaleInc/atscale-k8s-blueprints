
# Service Account for GKE nodes
resource "google_service_account" "gke_node" {
  account_id   = "${var.cluster_name}-node-sa"
  display_name = "GKE Node Service Account for ${var.cluster_name}"
  project      = var.project_id
}

# Grant necessary permissions to the node service account
resource "google_project_iam_member" "gke_node" {
  project = var.project_id
  role    = "roles/container.nodeServiceAccount"
  member  = "serviceAccount:${google_service_account.gke_node.email}"
}
