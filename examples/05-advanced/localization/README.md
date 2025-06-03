# Resource Localization Example

This example demonstrates customizing components for different environments using OCM's resource localization features.

## Overview

The Resource Localization example shows how to:
- Create environment-specific component variants
- Use localization labels and rules
- Customize resources for dev, staging, and production
- Implement environment-aware deployment strategies

## Files

- `create-localization-example.sh` - Main script demonstrating localization
- `work/dev-labels.yaml` - Development environment labels
- `work/prod-labels.yaml` - Production environment labels
- `work/base/` - Base component definition
- `work/dev/` - Development-specific resources
- `work/prod/` - Production-specific resources
- `work/staging/` - Staging-specific resources

## Running the Example

```bash
./create-localization-example.sh
```

## What it demonstrates

- Environment-specific resource customization
- Label-based resource selection
- Multi-environment component management
- Localization rule configuration
- Resource overlay patterns

## Use Cases

- Multi-environment deployments
- Configuration management across environments
- Feature flags and environment-specific behavior
- Resource optimization per environment
- Compliance and governance requirements

This example is essential for production-ready OCM implementations that need to support multiple deployment environments.
