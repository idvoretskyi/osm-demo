# OCM Demo Registry Module
# Terraform module for managing local container registry infrastructure

terraform {
  required_version = ">= 1.0"
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# Variables
variable "registry_port" {
  description = "Port for the local container registry"
  type        = number
  default     = 5001
}

variable "registry_name" {
  description = "Name of the registry container"
  type        = string
  default     = "local-registry"
}

variable "enable_kind_cluster" {
  description = "Whether to create a kind cluster"
  type        = bool
  default     = true
}

variable "cluster_name" {
  description = "Name of the kind cluster"
  type        = string
  default     = "ocm-demo"
}

variable "namespace" {
  description = "Kubernetes namespace for OCM demos"
  type        = string
  default     = "ocm-demos"
}

# Local registry container
resource "docker_image" "registry" {
  name = "registry:2"
}

resource "docker_container" "local_registry" {
  image = docker_image.registry.image_id
  name  = var.registry_name

  ports {
    internal = 5000
    external = var.registry_port
  }

  restart = "unless-stopped"

  labels {
    label = "ocm-demo-component"
    value = "registry"
  }
}

# Outputs
output "registry_url" {
  description = "URL of the local registry"
  value       = "localhost:${var.registry_port}"
}

output "registry_container_id" {
  description = "ID of the registry container"
  value       = docker_container.local_registry.id
}

output "cluster_name" {
  description = "Name of the cluster"
  value       = var.cluster_name
}

output "namespace" {
  description = "Kubernetes namespace"
  value       = var.namespace
}
