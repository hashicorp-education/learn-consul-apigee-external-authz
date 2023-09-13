/*****************************************
  GKE
 *****************************************/

resource "google_container_cluster" "primary" {
  project  = module.project.project_id
  name     = local.gke_cluster_name
  location = var.region

  node_locations           = ["${var.region}-a"]
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = module.vpc.network.name
  subnetwork = module.vpc.subnet_self_links[local.subnet_region_name[var.region]]

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
}

# create separately Managed Node Pool
resource "google_container_node_pool" "primary_nodes" {
  project    = module.project.project_id
  name       = google_container_cluster.primary.name
  cluster    = google_container_cluster.primary.name
  location   = var.region
  node_count = var.gke_num_nodes
  autoscaling {
    min_node_count = var.gke_min_num_nodes
    max_node_count = var.gke_max_num_nodes
  }

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    labels = {
      env = local.gke_cluster_name
    }

    machine_type    = "n1-standard-1"
    service_account = google_service_account.gke.email
    tags            = ["gke-node", local.gke_cluster_name]
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}

/*****************************************
  IAM bindings
 *****************************************/

# Create a new Service account for GKE
resource "google_service_account" "gke" {
  project      = module.project.project_id
  account_id   = "sa-${local.gke_cluster_name}"
  display_name = "GKE Service Account"
}

/*****************************************
  Consul
 *****************************************/

# Deploy Consul
resource "helm_release" "consul" {
  name             = try(var.consul_helm_config.name, "consul")
  namespace        = try(var.consul_helm_config.namespace, "consul")
  create_namespace = try(var.consul_helm_config.create_namespace, true)
  description      = try(var.consul_helm_config.description, null)
  chart            = "consul"
  version          = try(var.consul_helm_config.version, "1.1.2")
  repository       = try(var.consul_helm_config.repository, "https://helm.releases.hashicorp.com")
  values           = try(var.consul_helm_config.values, [file("${path.module}/consul-values.yaml")])
}

/*****************************************
  Export outputs
 *****************************************/

resource "local_file" "env_file" {
  filename = "${path.module}/../app/gcp.auto.tfvars"
  content  = <<EOT
gke_cluster_name="${google_container_cluster.primary.name}"
project_id="${var.project_id}"
apigee_env_name="${var.apigee_env_name}"
apigee_envgroup_name="${var.apigee_envgroup_name}"
apigee_runtime="https://${var.apigee_envgroup_name}.${module.nip-development-hostname.hostname}"
EOT
}
