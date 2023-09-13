terraform {
  required_version = ">= 0.13"
  required_providers {

    google = {
      source  = "hashicorp/google"
      version = ">= 4.3.0, < 5.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0, <3.0"
    }

    random = {
      source  = "hashicorp/random"
      version = ">= 3.4.3, < 4.0"
    }

    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0, < 3.0"
    }

    external = {
      source  = "hashicorp/external"
      version = ">= 2.3.0, < 3.0"
    }
  }
}

data "google_client_config" "provider" {}

provider "helm" {
  kubernetes {
    host  = "https://${google_container_cluster.primary.endpoint}"
    token = data.google_client_config.provider.access_token
    cluster_ca_certificate = base64decode(
      google_container_cluster.primary.master_auth[0].cluster_ca_certificate,
    )
  }
}
