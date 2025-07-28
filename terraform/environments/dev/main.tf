# Development Environment Configuration
# Terraform configuration for local development setup

terraform {
  required_version = ">= 1.0"
}

module "registry" {
  source = "../../modules/registry"

  registry_port      = 5001
  registry_name      = "ocm-demo-registry"
  enable_kind_cluster = true
  cluster_name       = "ocm-demo"
  namespace          = "ocm-demos"
}

# Outputs
output "registry_url" {
  description = "URL of the local registry"
  value       = module.registry.registry_url
}

output "cluster_name" {
  description = "Name of the cluster"
  value       = module.registry.cluster_name
}
