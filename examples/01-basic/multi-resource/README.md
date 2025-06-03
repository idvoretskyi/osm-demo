# Multi-Resource Component Example

This example demonstrates packaging different types of resources in a single OCM component.

## Overview

The Multi-Resource example shows how to create a more complex OCM component that includes:
- Configuration files (YAML)
- Documentation (Markdown)
- Executable scripts
- Application artifacts

## Files

- `create-component.sh` - Main script that creates the multi-resource component
- `work/config/app.yaml` - Application configuration resource
- `work/docs/README.md` - Documentation resource
- `work/scripts/deploy.sh` - Deployment script resource
- `work/component-labels.yaml` - Component labeling configuration

## Running the Example

```bash
./create-component.sh
```

## What it demonstrates

- Packaging multiple resource types in one component
- Organizing resources by type and purpose
- Resource labeling and metadata
- Complex component structures
- Resource extraction and deployment workflows

This example shows how OCM can handle real-world application packaging scenarios with multiple artifacts.
