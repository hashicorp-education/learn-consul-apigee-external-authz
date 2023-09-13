/*****************************************
  Locals
 *****************************************/

locals {
  subnet_region_name = { for subnet in var.exposure_subnets :
    subnet.region => "${subnet.region}/${subnet.name}"
  }
  apigee_envgroups = {
    "${var.apigee_envgroup_name}" = {
      hostnames = ["${var.apigee_envgroup_name}.${module.nip-development-hostname.hostname}"]
    }
  }
  apigee_instances = {
    usw1-instance = {
      region       = "us-west1"
      ip_range     = "10.0.0.0/22"
      key_name     = "inst-disk"
      environments = [var.apigee_env_name]
    }
  }
  apigee_environments = {
    "${var.apigee_env_name}" = {
      display_name = var.apigee_env_name
      description  = "Environment created by apigee/terraform-modules"
      node_config  = null
      iam          = null
      envgroups    = [var.apigee_envgroup_name]
    }
  }
  org_kms_keyring_name = "apigee-x-org-${random_string.suffix.result}"
  gke_cluster_name     = "gke-${random_string.suffix.result}"
}

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

/*****************************************
  GCP Project
 *****************************************/

module "project" {
  source          = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/project?ref=v16.0.0"
  name            = var.project_id
  parent          = var.project_parent
  billing_account = var.billing_account
  project_create  = var.project_create
  services = [
    "apigee.googleapis.com",
    "cloudkms.googleapis.com",
    "compute.googleapis.com",
    "servicenetworking.googleapis.com"
  ]
}

/*****************************************
  GCP Networking
 *****************************************/

module "vpc" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpc?ref=v16.0.0"
  project_id = module.project.project_id
  name       = var.network
  subnets    = var.exposure_subnets
  psa_config = {
    ranges = {
      apigee-range         = var.peering_range
      apigee-support-range = var.support_range
    }
    routes = null
  }
}


/*****************************************
  Apigee infrastructure
 *****************************************/

# Module to setup Apigee Core
module "apigee-x-core" {
  source               = "github.com/apigee/terraform-modules//modules/apigee-x-core"
  project_id           = module.project.project_id
  network              = module.vpc.network.id
  ax_region            = var.ax_region
  apigee_environments  = local.apigee_environments
  apigee_envgroups     = local.apigee_envgroups
  apigee_instances     = local.apigee_instances
  org_kms_keyring_name = local.org_kms_keyring_name
}

# Module to create Apigee Network Bridge Managed Instance Group
module "apigee-x-bridge-mig" {
  for_each    = local.apigee_instances
  source      = "github.com/apigee/terraform-modules//modules/apigee-x-bridge-mig"
  project_id  = module.project.project_id
  network     = module.vpc.network.id
  subnet      = module.vpc.subnet_self_links[local.subnet_region_name[each.value.region]]
  region      = each.value.region
  endpoint_ip = module.apigee-x-core.instance_endpoints[each.key]
}

# Module to create L7 Loadbalancer for Apigee Managed Instance Group Backend
module "mig-l7xlb" {
  source          = "github.com/apigee/terraform-modules//modules/mig-l7xlb"
  project_id      = module.project.project_id
  name            = "apigee-xlb"
  backend_migs    = [for _, mig in module.apigee-x-bridge-mig : mig.instance_group]
  ssl_certificate = [module.nip-development-hostname.ssl_certificate]
  external_ip     = module.nip-development-hostname.ip_address
}

# Module to create NIP.io Hostname for Development
module "nip-development-hostname" {
  source             = "github.com/apigee/terraform-modules//modules/nip-development-hostname"
  project_id         = module.project.project_id
  address_name       = "apigee-external"
  subdomain_prefixes = [var.apigee_envgroup_name]
}
