terraform {
  required_version = ">= 0.13"
  required_providers {

    google = {
      source  = "hashicorp/google"
      version = ">= 4.3.0, < 5.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0, <3.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0, <3.0"
    }

    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0, < 3.0"
    }

    apigee = {
      source  = "scastria/apigee"
      version = ">= 0.1.0, < 0.2.0"
    }
  }
}

provider "apigee" {
  organization = var.project_id
  server       = "apigee.googleapis.com"
}

data "google_client_config" "provider" {}

data "google_container_cluster" "default" {
  project  = var.project_id
  name     = var.gke_cluster_name
  location = var.gke_cluster_location
}

provider "kubernetes" {
  host  = "https://${data.google_container_cluster.default.endpoint}"
  token = data.google_client_config.provider.access_token
  cluster_ca_certificate = base64decode(
    data.google_container_cluster.default.master_auth[0].cluster_ca_certificate,
  )
}
