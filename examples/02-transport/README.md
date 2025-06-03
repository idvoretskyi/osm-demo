# 02-Transport: OCM Component Transport

This section demonstrates how to transport OCM components between different storage backends and registries.

## Examples in this section:

1. **local-to-oci** - Transport from local archive to OCI registry
2. **oci-to-oci** - Transport between OCI registries  
3. **cross-registry** - Cross-registry replication
4. **offline-transport** - Air-gapped transport using common transport format

## Learning Objectives:

- Understand OCM transport capabilities
- Learn about different storage backends
- Practice cross-registry operations
- Explore offline/air-gapped scenarios

## Prerequisites:

- OCM CLI installed
- Docker running
- Basic examples completed (`../01-basic/run-examples.sh`)

## Quick Start:

```bash
# Run all transport examples
./run-examples.sh

# Or run individual examples
cd local-to-oci && ./transport-example.sh
```

## Transport Types Covered:

- **OCI Registry**: Standard container registry storage
- **Local Archive**: File-based component archives
- **Common Transport Format**: For offline scenarios
- **Cross-Registry**: Between different registry instances

## What you'll learn:

After completing these examples, you'll understand:
- How to move components between storage types
- Cross-registry replication strategies
- Offline transport mechanisms
- Registry authentication and configuration
