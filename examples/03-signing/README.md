# 03-Signing: OCM Component Signing and Verification

This section demonstrates OCM's cryptographic signing capabilities for ensuring component integrity and provenance.

## Examples in this section:

1. **basic-signing** - Sign components with RSA keys
2. **signature-verification** - Verify component signatures
3. **key-management** - Key generation and management
4. **trust-policies** - Define and enforce trust policies

## Learning Objectives:

- Understand OCM signature mechanisms
- Learn key generation and management
- Practice signing and verification workflows
- Explore trust policy enforcement

## Prerequisites:

- OCM CLI installed
- OpenSSL (for key generation)
- Transport examples completed (`../02-transport/`)

## Quick Start:

```bash
# Run all signing examples
./run-examples.sh

# Or run individual examples
cd basic-signing && ./sign-component.sh
```

## Security Features Covered:

- **Digital Signatures**: RSA and ECDSA signing
- **Key Management**: Key generation and storage
- **Signature Verification**: Automated verification workflows
- **Trust Policies**: Policy-based signature validation
- **Provenance**: Source code and build provenance

## What you'll learn:

After completing these examples, you'll understand:
- How to generate and manage signing keys
- Component signing workflows
- Signature verification processes
- Trust policy configuration and enforcement
- Security best practices for component distribution
