/*****************************************
  Project settings
 *****************************************/

variable "project_id" {
  description = "Project id (also used for the Apigee Organization)"
  type        = string
}

variable "region" {
  description = "GCP region for non Apigee resources"
  default     = "us-west1"
}

variable "project_parent" {
  description = "Parent folder or organization in 'folders/folder_id' or 'organizations/org_id' format"
  type        = string
  default     = null
  validation {
    condition     = var.project_parent == null || can(regex("(organizations|folders)/[0-9]+", var.project_parent))
    error_message = "Parent must be of the form folders/folder_id or organizations/organization_id"
  }
}

variable "project_create" {
  description = "Create project. When set to false, uses a data source to reference existing project"
  type        = bool
  default     = false
}

variable "billing_account" {
  description = "Billing account id"
  type        = string
  default     = null
}

/*****************************************
  Network settings
 *****************************************/

variable "network" {
  description = "VPC name"
  type        = string
  default     = "apigee-network"
}

variable "peering_range" {
  description = "Peering CIDR range"
  type        = string
  default     = "10.0.0.0/22"
}

variable "support_range" {
  description = "Support CIDR range of length /28 (required by Apigee for troubleshooting purposes)."
  type        = string
  default     = "10.1.0.0/28"
}

variable "exposure_subnets" {
  description = "Subnets for exposing Apigee services"
  type = list(object({
    name               = string
    ip_cidr_range      = string
    region             = string
    secondary_ip_range = map(string)
  }))
  default = [
    {
      name               = "apigee-exposure"
      ip_cidr_range      = "10.100.0.0/24"
      region             = "us-west1"
      secondary_ip_range = null
    }
  ]
}

/*****************************************
  GKE settings
 *****************************************/

variable "gke_num_nodes" {
  description = "min number of gke nodes"
  default     = 2
}

variable "gke_min_num_nodes" {
  description = "min number of gke nodes"
  default     = 1
}

variable "gke_max_num_nodes" {
  description = "max number of gke nodes"
  default     = 3
}

/*****************************************
  Apigee settings
 *****************************************/

variable "ax_region" {
  description = "GCP region for storing Apigee analytics data (see https://cloud.google.com/apigee/docs/api-platform/get-started/install-cli)"
  type        = string
  default     = "us-west1"
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

variable "apigee_envgroups" {
  description = "Apigee Environment Groups"
  type = map(object({
    hostnames = list(string)
  }))
  default = null
}

variable "apigee_instances" {
  description = "Apigee Instances (only one instance for EVAL orgs)"
  type = map(object({
    region       = string
    ip_range     = string
    environments = list(string)
  }))
  default = null
}

variable "apigee_environments" {
  description = "Apigee Environments"
  type = map(object({
    display_name = optional(string)
    description  = optional(string)
    node_config = optional(object({
      min_node_count = optional(number)
      max_node_count = optional(number)
    }))
    iam       = optional(map(list(string)))
    envgroups = list(string)
  }))
  default = null
}

/*****************************************
  Consul settings
 *****************************************/

variable "consul_helm_config" {
  description = "HashiCorp Consul Helm chart configuration"
  type        = any
  default     = {}
}
