output "project_id" {
  description = "GCP project id"
  value       = module.project.project_id
}

output "region" {
  value       = var.region
  description = "Google Cloud region to deploy resources"
}

output "gke_cluster_name" {
  value       = google_container_cluster.primary.name
  description = "GKE Cluster name"
}

output "gke_cluster_location" {
  value       = google_container_cluster.primary.location
  description = "GKE Cluster location"
}

output "apigee_env_name" {
  description = "Apigee Environment name"
  value       = var.apigee_env_name
}

output "apigee_envgroup_name" {
  description = "Apigee Environment Group name"
  value       = var.apigee_envgroup_name
}

output "apigee_instance_endpoints" {
  description = "Apigee instance endpoint"
  value       = module.apigee-x-core.instance_endpoints
}

output "apigee_runtime" {
  description = "Generated hostname (nip.io encoded IP address)"
  value       = "https://${var.apigee_envgroup_name}.${module.nip-development-hostname.hostname}"
}
