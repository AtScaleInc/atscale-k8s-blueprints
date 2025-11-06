# ################################################################################
# # Cluster
# ################################################################################

output "region" {
  value = local.region
}

output "project_id" {
  value = local.project_id
}

output "cluster_name" {
  value = local.cluster_name
}

output "cluster_get_credentials_command" {
  description = "Command to get credentials for the GKE cluster"
  value       = "gcloud container clusters get-credentials ${local.cluster_name} --region ${local.region} --project ${local.project_id}"
}
