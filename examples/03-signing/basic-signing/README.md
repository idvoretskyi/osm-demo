# Basic Component Signing Example

This example demonstrates signing OCM components with digital signatures for security and integrity.

## Overview

The Basic Signing example shows how to:
- Generate signing keys
- Sign OCM components
- Verify component signatures
- Manage signing credentials

## Files

- `sign-component.sh` - Main script that demonstrates component signing
- `work/keys/` - Directory for generated signing keys
- `work/components/` - Directory for signed components

## Running the Example

```bash
./sign-component.sh
```

## What it demonstrates

- Digital signature generation and management
- Component signing workflow
- Signature verification process
- Security best practices for component integrity
- Key management in OCM

## Prerequisites

- OCM CLI with signing support
- OpenSSL or compatible crypto tools

This example is essential for understanding OCM security features and establishing trust in component distribution.
