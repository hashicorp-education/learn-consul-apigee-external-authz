# Configure external authorization
resource "kubernetes_manifest" "service_a_service_defaults" {
  count = var.ext_authz ? 1 : 0
  manifest = {
    "apiVersion" = "consul.hashicorp.com/v1alpha1"
    "kind"       = "ServiceDefaults"
    "metadata" = {
      "name"      = var.service_a_name
      "namespace" = var.service_a_namespace
    }
    "spec" = {
      "protocol" = "http"
      "envoyExtensions" = [
        {
          "name"     = "builtin/ext-authz"
          "required" = "true"
          "arguments" = {
            "proxyType" = "connect-proxy"
            "config" = {
              "grpcService" = {
                "target" = {
                  "service" = {
                    "name" = "apigee-remote-service-envoy"
                  }
                }
              }
            }
          }
        }
      ]
    }
  }
}

# Configure service default for apigee envoy adapter
resource "kubernetes_manifest" "service_defaults" {
  manifest = {
    "apiVersion" = "consul.hashicorp.com/v1alpha1"
    "kind"       = "ServiceDefaults"
    "metadata" = {
      "name"      = "apigee-remote-service-envoy"
      "namespace" = kubernetes_namespace.apigee_remote_service_namespace.metadata[0].name
    }
    "spec" = {
      "protocol" = "grpc"
    }
  }
}

# Configure consul service intentions from Service B -> Service A
resource "kubernetes_manifest" "serviceB_to_serviceA" {
  manifest = {
    "apiVersion" = "consul.hashicorp.com/v1alpha1"
    "kind"       = "ServiceIntentions"
    "metadata" = {
      "name"      = var.service_b_name
      "namespace" = var.service_b_namespace
    }
    "spec" = {
      "destination" = {
        "name" = var.service_a_name
      }
      "sources" = [
        {
          "name"   = var.service_b_name
          "action" = "allow"
        }
      ]
    }
  }
}

# Configure consul service intentions from Service A -> Apigee Remote proxy
resource "kubernetes_manifest" "serviceA_to_proxy" {
  manifest = {
    "apiVersion" = "consul.hashicorp.com/v1alpha1"
    "kind"       = "ServiceIntentions"
    "metadata" = {
      "name"      = var.service_a_name
      "namespace" = var.service_a_namespace
    }
    "spec" = {
      "destination" = {
        "name" = "apigee-remote-service-envoy"
      }
      "sources" = [
        {
          "name"   = var.service_a_name
          "action" = "allow"
        }
      ]
    }
  }
}
