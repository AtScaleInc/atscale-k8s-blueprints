output "vpc_id" {
  description = "The ID of the VPC network"
  value       = google_compute_network.vpc.id
}

output "vpc_name" {
  description = "The name of the VPC network"
  value       = google_compute_network.vpc.name
}

output "vpc_self_link" {
  description = "The self link of the VPC network"
  value       = google_compute_network.vpc.self_link
}

output "subnet_id" {
  description = "The ID of the subnet"
  value       = google_compute_subnetwork.gke_subnet.id
}

output "subnet_name" {
  description = "The name of the subnet"
  value       = google_compute_subnetwork.gke_subnet.name
}

output "subnet_self_link" {
  description = "The self link of the subnet"
  value       = google_compute_subnetwork.gke_subnet.self_link
}

output "subnet_cidr" {
  description = "The CIDR block of the subnet"
  value       = google_compute_subnetwork.gke_subnet.ip_cidr_range
}

output "pods_secondary_range_name" {
  description = "The name of the pods secondary IP range"
  value       = "pods"
}

output "pods_secondary_range_cidr" {
  description = "The CIDR block of the pods secondary IP range"
  value       = var.pods_secondary_range_cidr
}

output "services_secondary_range_name" {
  description = "The name of the services secondary IP range"
  value       = "services"
}

output "services_secondary_range_cidr" {
  description = "The CIDR block of the services secondary IP range"
  value       = var.services_secondary_range_cidr
}
