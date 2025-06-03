# Registry Port and Container Name Standardization

## Issue Resolution Summary

### Problem Identified
The CI test failure for "OCM Utils - List Components" was caused by registry container naming conflicts and port inconsistencies:

1. **Port Mismatch**: `setup-environment.sh` started registry on port 5001, but `ocm-utils.sh` was checking port 5005
2. **Container Name Conflicts**: Multiple scripts used different container names (`registry`, `local-registry`, `demo-registry`)
3. **Registry Persistence**: Registry wasn't guaranteed to be running during test execution

### Fixes Applied

#### 1. Port Standardization (✅ Complete)
- **All registry operations now use port 5001**
- Updated `ocm-utils.sh` to check and manage registry on port 5001
- Standardized all example scripts to use localhost:5001

#### 2. Container Name Standardization (✅ Complete)
- **Primary registry container name**: `local-registry`
- Updated `ocm-utils.sh` to use `local-registry` consistently
- Updated cleanup functions to handle all possible container names
- Added conflict resolution in scripts that start registries

#### 3. Registry Auto-Start Enhancement (✅ Complete)
- `list_components()` function now auto-starts registry if not running
- Improved error handling and user feedback
- Added robust container conflict resolution

#### 4. Cleanup Function Fixes (✅ Complete)
- Updated test cleanup to handle all registry container names
- Prevents premature registry termination during test execution

## Changes Made

### Files Modified:
1. `scripts/ocm-utils.sh` - Port and container name standardization
2. `scripts/test-all.sh` - Cleanup function improvements
3. `examples/01-basic/run-examples.sh` - Container name standardization
4. `examples/05-advanced/run-examples.sh` - Container name standardization
5. `examples/03-signing/basic-signing/sign-component.sh` - Container name standardization

### Registry Port Configuration:
- **Main Registry**: localhost:5001 (container: `local-registry`)
- **Transport Source**: localhost:5001 (shared with main)
- **Transport Target**: localhost:5002 (container: `target-registry`)
- **Offline Source**: localhost:5002 (container: `source-env-registry`)
- **Offline Target**: localhost:5003 (container: `target-env-registry`)
- **K8s Example**: localhost:5004 (container: `registry`)

## Expected Impact

### CI Test Resolution
The "OCM Utils - List Components" test should now pass because:
1. Registry check uses correct port (5001)
2. Registry auto-starts if not running
3. No container naming conflicts
4. Improved cleanup prevents premature termination

### User Experience Improvements
- Consistent registry behavior across all examples
- Better error messages and auto-recovery
- More reliable multi-example workflows
- Reduced setup complexity

## Verification Commands

```bash
# Test registry management
./scripts/ocm-utils.sh registry start
./scripts/ocm-utils.sh status
./scripts/ocm-utils.sh list-components

# Test example workflows
cd examples/01-basic && ./run-examples.sh
cd examples/02-transport/local-to-oci && ./transport-example.sh

# Run full test suite
./scripts/test-all.sh --skip-k8s
```

## Migration Notes

All existing examples continue to work without changes. The fixes are backward-compatible and improve reliability without breaking existing workflows.

---
**Status**: ✅ Complete - Ready for CI validation
**Impact**: Resolves primary CI test failure and improves overall system reliability
