output "cluster_id" {
  description = "The ID of the GKE cluster"
  value       = google_container_cluster.primary.id
}

output "cluster_name" {
  description = "The name of the GKE cluster"
  value       = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  description = "The endpoint for the GKE cluster"
  value       = google_container_cluster.primary.endpoint
}

output "cluster_ca_certificate" {
  description = "The base64 encoded public certificate that is the root of trust for the cluster"
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "cluster_location" {
  description = "The location of the GKE cluster"
  value       = google_container_cluster.primary.location
}

output "cluster_region" {
  description = "The region of the GKE cluster"
  value       = var.region
}

output "cluster_project_id" {
  description = "The project ID of the GKE cluster"
  value       = var.project_id
}

output "node_pool_id" {
  description = "The ID of the node pool"
  value       = google_container_node_pool.primary.id
}

output "node_pool_name" {
  description = "The name of the node pool"
  value       = google_container_node_pool.primary.name
}
