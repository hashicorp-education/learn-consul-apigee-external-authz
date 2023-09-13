/*****************************************
  Service A
 *****************************************/

resource "kubernetes_service_account" "service_a" {
  metadata {
    name      = var.service_a_name
    namespace = var.service_a_namespace
  }
}

resource "kubernetes_service" "service_a" {
  metadata {
    name      = var.service_a_name
    namespace = var.service_a_namespace
    labels = {
      app = var.service_a_name
    }
  }
  spec {
    selector = {
      app = var.service_a_name
    }
    port {
      port        = var.service_a_port
      target_port = var.service_a_port
    }
  }
}

resource "kubernetes_deployment" "service_a" {
  metadata {
    name      = var.service_a_name
    namespace = var.service_a_namespace
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app     = var.service_a_name
        version = "v1"
      }
    }

    template {
      metadata {
        labels = {
          app     = var.service_a_name
          version = "v1"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.service_a.metadata[0].name

        container {
          image   = var.service_a_image
          name    = var.service_a_name
          command = var.service_a_cmd
          port {
            container_port = var.service_a_port
          }
          dynamic "env" {
            for_each = var.service_a_env == null ? [] : var.service_a_env
            content {
              name  = env.value.name
              value = env.value.value
            }
          }
        }
      }
    }
  }
}

/*****************************************
  Service B
 *****************************************/

resource "kubernetes_service_account" "service_b" {
  metadata {
    name      = var.service_b_name
    namespace = var.service_b_namespace
  }
}

resource "kubernetes_service" "service_b" {
  metadata {
    name      = var.service_b_name
    namespace = var.service_b_namespace
    labels = {
      app = var.service_b_name
    }
  }
  spec {
    selector = {
      app = var.service_b_name
    }
    port {
      port        = var.service_b_port
      target_port = var.service_b_port
    }
  }
}

resource "kubernetes_deployment" "service_b" {
  metadata {
    name        = var.service_b_name
    namespace   = var.service_b_namespace
    annotations = var.service_b_annotations == null ? {} : var.service_b_annotations
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app     = var.service_b_name
        version = "v1"
      }
    }

    template {
      metadata {
        labels = {
          app     = var.service_b_name
          version = "v1"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.service_b.metadata[0].name

        container {
          image   = var.service_b_image
          name    = var.service_b_name
          command = var.service_b_cmd
          port {
            container_port = var.service_b_port
          }
          dynamic "env" {
            for_each = var.service_b_env == null ? [] : var.service_b_env
            content {
              name  = env.value.name
              value = env.value.value
            }
          }
          # Env block specifically for Apigee developer API key
          dynamic "env" {
            for_each = var.ext_authz ? [var.service_b_api_env] : []
            content {
              name  = var.service_b_api_env
              value = random_string.consumer_key.result
            }
          }
        }
      }
    }
  }
}
