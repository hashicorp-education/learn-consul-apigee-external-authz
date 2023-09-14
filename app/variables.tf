/*****************************************
  GCP settings
 *****************************************/

variable "project_id" {
  description = "Project id (also used for the Apigee Organization)"
  type        = string
}

variable "region" {
  description = "GCP region for non Apigee resources"
  default     = "us-west1"
}

variable "gke_cluster_name" {
  description = "GKE cluster name"
  type        = string
}

variable "gke_cluster_location" {
  description = "GKE cluster location"
  default     = "us-west1"
}

/*****************************************
  Consul settings
 *****************************************/

variable "ext_authz" {
  description = "Enable external authorization for Consul to Apigee"
  type        = bool
  default     = false
}

/*****************************************
  Apigee settings
 *****************************************/

variable "apigee_runtime" {
  description = "Apigee runtime URL"
  type        = string
}

variable "apigee_env_name" {
  description = "Name for the Apigee environment"
  type        = string
  default     = "env"
}

variable "apigee_envgroup_name" {
  description = "Name for the Apigee environment group"
  type        = string
  default     = "envgroup"
}

variable "apigee_product_name" {
  description = "Name for the Apigee product"
  type        = string
  default     = "httpbin-product"
}

variable "apigee_app_name" {
  description = "Name for the Apigee app"
  type        = string
  default     = "httpbin-app"
}

variable "apigee_developer" {
  description = "Name for the Apigee developer"
  type        = any
  default = {
    email      = "ahamilton@example.com"
    first_name = "Alex"
    last_name  = "Hamilton"
    user_name  = "ahamilton"
  }
}

variable "apigee_remote_namespace" {
  description = "K8s namespace where to install the remote proxy agent"
  type        = string
  default     = "apigee"
}

variable "apigee_remote_version" {
  description = "Version of the remote proxy agent (see https://github.com/apigee/apigee-remote-service-envoy/tree/main)"
  type        = string
  default     = "2.1.1"
}

variable "apigee_sa_filename" {
  description = "Filename for Service Account used for Apigee analytics"
  type        = string
  default     = "apigee_sa_analytics.json"
}

variable "apigee_sa_roles_list" {
  description = "Roles required for the Service Account"
  type        = list(string)
  default = [
    "roles/apigee.analyticsAgent",
  ]
}

/*****************************************
  App settings
 *****************************************/

variable "service_a_name" {
  description = "Service A, which defers to the ext_authz service"
  type        = string
  default     = "httpbin"
}

variable "service_a_namespace" {
  description = "Namespace for service A"
  type        = string
  default     = "default"
}

variable "service_a_image" {
  description = "Docker image for service A"
  type        = string
  default     = "docker.io/kennethreitz/httpbin"
}

variable "service_a_port" {
  description = "Container port for service A"
  type        = string
  default     = "80"
}

variable "service_a_cmd" {
  description = "An array of commands to execute for service A"
  type        = list(string)
  default     = null
}

variable "service_a_env" {
  description = "List of environment variables for the service A"
  type = list(object({
    name  = string
    value = string
  }))
  default = null
}

variable "service_b_name" {
  description = "Service B, which is trying to communicate with service B"
  type        = string
  default     = "curl"
}

variable "service_b_namespace" {
  description = "Namespace for service B"
  type        = string
  default     = "default"
}

variable "service_b_image" {
  description = "Docker image for service B"
  type        = string
  default     = "curlimages/curl"
}

variable "service_b_port" {
  description = "Container port for service B"
  type        = string
  default     = "80"
}

variable "service_b_cmd" {
  description = "An array of commands to execute for service B"
  type        = list(string)
  default     = ["/bin/sleep", "infinity"]
}

variable "service_b_annotations" {
  description = "List of annotations for the service B"
  type        = map(string)
  default     = null
}

variable "service_b_env" {
  description = "List of environment variables for the service B"
  type = list(object({
    name  = string
    value = string
  }))
  default = null
}

variable "service_b_api_env" {
  description = "Name of the environment variable to store Apigee developer API key for the service B"
  type        = string
  default     = "API_KEY"
}
