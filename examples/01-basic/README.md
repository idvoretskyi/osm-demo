# 01-Basic: OCM Component Fundamentals

This section demonstrates the core concepts of the Open Component Model through simple, hands-on examples.

## Examples in this section:

1. **hello-world** - Create your first OCM component
2. **multi-resource** - Components with multiple resources
3. **metadata-labels** - Adding metadata and labels
4. **source-references** - Linking to source code

## Learning Objectives:

- Understand OCM component descriptors
- Learn about resources and their access types
- Practice creating and inspecting components
- Explore OCM CLI basic commands

## Prerequisites:

- OCM CLI installed (run `../scripts/setup-environment.sh` if needed)
- Docker running (for local OCI registry)

## Quick Start:

```bash
# Run all basic examples
./run-examples.sh

# Or run individual examples
cd hello-world && ./create-component.sh
```

## What you'll learn:

After completing these examples, you'll understand:
- How to create OCM component descriptors
- Different resource access types (ociArtifact, localBlob, etc.)
- How to add metadata and source references
- Basic OCM CLI operations (create, add, push, get)
