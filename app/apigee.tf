/*****************************************
  Install Apigee envoy adapter svc
 *****************************************/

resource "google_service_account" "apigee_service_account" {
  project      = var.project_id
  account_id   = "apigee-service-account"
  display_name = "Apigee Service Account (created by Terraform)"
}

resource "google_project_iam_member" "apigee_member" {
  project  = var.project_id
  for_each = toset(var.apigee_sa_roles_list)
  role     = each.value
  member   = "serviceAccount:${google_service_account.apigee_service_account.email}"
}

resource "google_service_account_key" "apigee_service_account_key" {
  service_account_id = google_service_account.apigee_service_account.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}

resource "local_file" "sa_key_json" {
  filename = "${path.module}/scripts/${var.apigee_sa_filename}"
  content  = base64decode(google_service_account_key.apigee_service_account_key.private_key)
}

data "external" "apigee_remote_setup" {
  depends_on = [local_file.sa_key_json]
  program    = ["bash", "${path.module}/scripts/apigee-remote-service-cli.sh"]
  query = {
    project_id            = var.project_id
    apigee_runtime        = var.apigee_runtime
    apigee_env_name       = var.apigee_env_name
    apigee_namespace      = var.apigee_remote_namespace
    apigee_remote_version = var.apigee_remote_version
    apigee_analytics_sa   = "${path.module}/scripts/${var.apigee_sa_filename}"
  }
}

/*****************************************
  Configure Apigee resources
 *****************************************/

resource "random_string" "consumer_key" {
  length  = 48
  special = false
}

resource "random_password" "consumer_secret" {
  length  = 64
  special = false
}

# Create a new Apigee developer
resource "apigee_developer" "apigee_dev" {
  email      = var.apigee_developer.email
  first_name = var.apigee_developer.first_name
  last_name  = var.apigee_developer.last_name
  user_name  = var.apigee_developer.user_name
}

# Create a new Apigee product
resource "apigee_product" "apigee_product" {
  name               = var.apigee_product_name
  display_name       = var.apigee_product_name
  auto_approval_type = true
  description        = "A ${var.apigee_product_name} product"
  environments = [
    var.apigee_env_name
  ]
  attributes = {
    access = "public"
  }
  operation {
    api_source = "${var.service_a_name}.default.svc.cluster.local"
    path       = "/"
    methods    = ["GET", "PATCH", "POST", "PUT", "DELETE", "HEAD", "CONNECT", "OPTIONS", "TRACE"]
  }
  operation_config_type = "remoteservice"
}

# Create a new Apigee developer app
resource "apigee_developer_app" "apigee_app" {
  developer_email = apigee_developer.apigee_dev.email
  name            = var.apigee_app_name
}

# Create the credentials for the developer
resource "apigee_developer_app_credential" "apigee_app_creds" {
  developer_email    = apigee_developer.apigee_dev.email
  developer_app_name = apigee_developer_app.apigee_app.name
  consumer_key       = random_string.consumer_key.result
  consumer_secret    = random_password.consumer_secret.result
  api_products = [
    apigee_product.apigee_product.name
  ]
}

/*****************************************
  Apigee envoy adapter k8s deployment & SVC
 *****************************************/

resource "kubernetes_namespace" "apigee_remote_service_namespace" {
  count = var.apigee_remote_namespace == "default" ? 0 : 1
  metadata {
    name = var.apigee_remote_namespace
  }
}

resource "kubernetes_deployment" "apigee_remote_service_envoy" {
  depends_on = [data.external.apigee_remote_setup]
  metadata {
    name      = "apigee-remote-service-envoy"
    namespace = var.apigee_remote_namespace
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "apigee-remote-service-envoy"
      }
    }

    template {
      metadata {
        annotations = {
          "prometheus.io/path"   = "/metrics"
          "prometheus.io/port"   = "5001"
          "prometheus.io/scheme" = "https"
          "prometheus.io/scrape" = "true"
          "prometheus.io/type"   = "prometheusspec"
        }
        labels = {
          app     = "apigee-remote-service-envoy"
          version = "v1"
          org     = "${var.project_id}"
          env     = "${var.apigee_env_name}"
        }
      }

      spec {
        service_account_name = "apigee-remote-service-envoy"

        security_context {
          run_as_user     = 999
          run_as_group    = 999
          run_as_non_root = true
        }

        container {
          name              = "apigee-remote-service-envoy"
          image             = "google/apigee-envoy-adapter:v2.1.1"
          image_pull_policy = "IfNotPresent"

          port {
            container_port = 5000
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = 5001
            }
            failure_threshold = 1
            period_seconds    = 10
          }

          readiness_probe {
            http_get {
              path = "/healthz"
              port = 5001
            }
            failure_threshold = 30
            period_seconds    = 10
          }

          args = ["--log-level=debug", "--config=/config/config.yaml"]

          resources {
            limits = {
              cpu    = "100m"
              memory = "100Mi"
            }
            requests = {
              cpu    = "10m"
              memory = "100Mi"
            }
          }

          volume_mount {
            mount_path = "/config"
            name       = "apigee-remote-service-envoy"
            read_only  = true
          }

          volume_mount {
            mount_path = "/policy-secret"
            name       = "policy-secret"
            read_only  = true
          }

          volume_mount {
            mount_path = "/analytics-secret"
            name       = "analytics-secret"
            read_only  = true
          }
        }
        volume {
          name = "apigee-remote-service-envoy"
          config_map {
            name = "apigee-remote-service-envoy"
          }
        }
        volume {
          name = "policy-secret"
          secret {
            default_mode = "0644"
            secret_name  = "${var.project_id}-${var.apigee_env_name}-policy-secret"
          }
        }
        volume {
          name = "analytics-secret"
          secret {
            default_mode = "0644"
            secret_name  = "${var.project_id}-${var.apigee_env_name}-analytics-secret"
          }
        }
      }
    }
  }
}

# Apigee remote proxy service
resource "kubernetes_service" "apigee_remote_service_envoy" {
  metadata {
    name      = "apigee-remote-service-envoy"
    namespace = var.apigee_remote_namespace
    labels = {
      app = "apigee-remote-service-envoy"
      org = "${var.project_id}"
      env = "${var.apigee_env_name}"
    }
  }

  spec {
    selector = {
      app = "apigee-remote-service-envoy"
    }

    port {
      port = 5000
      name = "grpc"
    }
  }
}

# Apigee remote proxy ConfigMap
resource "kubernetes_service_account" "apigee_remote_service_envoy_sa" {
  metadata {
    name      = "apigee-remote-service-envoy"
    namespace = var.apigee_remote_namespace
    labels = {
      org = "${var.project_id}"
    }
  }
}

# Apigee remote proxy ConfigMap
# For more options, refer: https://cloud.google.com/apigee/docs/api-platform/envoy-adapter/v2.0.x/reference#configuration-file
resource "kubernetes_config_map" "apigee_remote_service_envoy_config" {
  metadata {
    name      = "apigee-remote-service-envoy"
    namespace = var.apigee_remote_namespace
  }

  data = {
    "config.yaml" = <<-EOT
      tenant:
        remote_service_api: ${var.apigee_runtime}/remote-service
        org_name: ${var.project_id}
        env_name: ${var.apigee_env_name}
      analytics:
        collection_interval: 10s
      auth:
        jwt_provider_key: ${var.apigee_runtime}/remote-token/token
        append_metadata_headers: true
    EOT
  }
}

# Apigee remote proxy policy secret
resource "kubernetes_secret" "apigee_remote_service_envoy_policy_secret" {
  metadata {
    name      = "${var.project_id}-${var.apigee_env_name}-policy-secret"
    namespace = var.apigee_remote_namespace
  }

  data = {
    "remote-service.crt"        = base64decode(data.external.apigee_remote_setup.result["apigee_remote_cert"])
    "remote-service.key"        = base64decode(data.external.apigee_remote_setup.result["apigee_remote_key"])
    "remote-service.properties" = base64decode(data.external.apigee_remote_setup.result["apigee_remote_properties"])
  }

  type = "opaque"
}

# Apigee remote proxy analytics secret
resource "kubernetes_secret" "apigee_remote_service_envoy_analytics_secret" {
  metadata {
    name      = "${var.project_id}-${var.apigee_env_name}-analytics-secret"
    namespace = var.apigee_remote_namespace
  }

  data = {
    "client_secret.json" = base64decode(data.external.apigee_remote_setup.result["client_secret"])
  }

  type = "opaque"
}
