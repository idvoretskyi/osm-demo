# 04-K8s-Deployment: OCM Kubernetes Integration

This section demonstrates deploying OCM components to Kubernetes using various tools and patterns.

## Examples in this section:

1. **ocm-k8s-toolkit** - Deploy using OCM K8s Toolkit and Kro
2. **flux-integration** - GitOps deployment with FluxCD
3. **helm-charts** - OCM components containing Helm charts
4. **component-references** - Components referencing other components

## Learning Objectives:

- Deploy OCM components to Kubernetes
- Integrate with OCM K8s Toolkit and Kro
- Use FluxCD for GitOps workflows
- Manage component dependencies

## Prerequisites:

- kind installed
- kubectl configured
- OCM CLI installed
- Flux CLI installed
- Previous examples completed

## Quick Start:

```bash
# Setup local Kubernetes cluster
./setup-cluster.sh

# Run all deployment examples
./run-examples.sh

# Or run individual examples
cd ocm-k8s-toolkit && ./deploy-example.sh
```

## Tools and Patterns Covered:

- **OCM K8s Toolkit**: Native OCM Kubernetes integration
- **Kro**: OCM Kubernetes Resource Operator
- **FluxCD**: GitOps continuous delivery
- **Helm Charts**: Packaged applications
- **Component References**: Multi-component applications

## What you'll learn:

After completing these examples, you'll understand:
- How to deploy OCM components to Kubernetes
- Integration with cloud-native tools
- GitOps workflows with OCM
- Component dependency management
- Production deployment patterns
