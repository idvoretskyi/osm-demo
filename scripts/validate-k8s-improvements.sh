#!/bin/bash

# Quick validation script for Kubernetes context improvements
# Tests the enhanced context management and debugging capabilities

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Kubernetes Context Improvements Validation${NC}"
echo "=============================================="

# Test 1: Validate script syntax
echo -e "${YELLOW}Test 1: Script Syntax Validation${NC}"
if bash -n "$PROJECT_ROOT/examples/04-k8s-deployment/ocm-k8s-toolkit/deploy-example.sh"; then
    echo -e "${GREEN}✅ Deploy script syntax is valid${NC}"
else
    echo -e "${RED}❌ Deploy script has syntax errors${NC}"
    exit 1
fi

if bash -n "$PROJECT_ROOT/scripts/test-all.sh"; then
    echo -e "${GREEN}✅ Test script syntax is valid${NC}"
else
    echo -e "${RED}❌ Test script has syntax errors${NC}"
    exit 1
fi

# Test 2: Check for required functions
echo -e "${YELLOW}Test 2: Function Availability${NC}"
if grep -q "ensure_k8s_connectivity()" "$PROJECT_ROOT/examples/04-k8s-deployment/ocm-k8s-toolkit/deploy-example.sh"; then
    echo -e "${GREEN}✅ ensure_k8s_connectivity function found${NC}"
else
    echo -e "${RED}❌ ensure_k8s_connectivity function missing${NC}"
    exit 1
fi

# Test 3: Check for debugging enhancements
echo -e "${YELLOW}Test 3: Debugging Enhancements${NC}"
if grep -q "Port connectivity test" "$PROJECT_ROOT/examples/04-k8s-deployment/ocm-k8s-toolkit/deploy-example.sh"; then
    echo -e "${GREEN}✅ Port connectivity testing added${NC}"
else
    echo -e "${RED}❌ Port connectivity testing missing${NC}"
    exit 1
fi

if grep -q "nc -z" "$PROJECT_ROOT/examples/04-k8s-deployment/ocm-k8s-toolkit/deploy-example.sh"; then
    echo -e "${GREEN}✅ Netcat port testing implemented${NC}"
else
    echo -e "${RED}❌ Netcat port testing missing${NC}"
    exit 1
fi

# Test 4: Check troubleshooting documentation
echo -e "${YELLOW}Test 4: Documentation Updates${NC}"
if grep -q "CI/CD Environment Specific Issues" "$PROJECT_ROOT/docs/troubleshooting.md"; then
    echo -e "${GREEN}✅ CI-specific troubleshooting added${NC}"
else
    echo -e "${RED}❌ CI-specific troubleshooting missing${NC}"
    exit 1
fi

# Test 5: Verify error handling improvements
echo -e "${YELLOW}Test 5: Error Handling${NC}"
if grep -q "API Server Connectivity Debug" "$PROJECT_ROOT/examples/04-k8s-deployment/ocm-k8s-toolkit/deploy-example.sh"; then
    echo -e "${GREEN}✅ Enhanced API server debugging found${NC}"
else
    echo -e "${RED}❌ Enhanced API server debugging missing${NC}"
    exit 1
fi

# Test 6: Test with verify-only flag (if cluster tools available)
echo -e "${YELLOW}Test 6: Verify-Only Mode${NC}"
if command -v kind &> /dev/null && command -v kubectl &> /dev/null; then
    cd "$PROJECT_ROOT"
    if ./examples/04-k8s-deployment/ocm-k8s-toolkit/deploy-example.sh --help | grep -q "verify-only"; then
        echo -e "${GREEN}✅ Verify-only mode available${NC}"
        echo "  Note: Run with --verify-only to test cluster verification without deployment"
    else
        echo -e "${RED}❌ Verify-only mode not available${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  Kind/kubectl not available, skipping verify-only test${NC}"
fi

echo ""
echo -e "${GREEN}🎉 All validation tests passed!${NC}"
echo -e "${BLUE}📋 Summary of Improvements:${NC}"
echo "   ✅ Enhanced Kubernetes context management"
echo "   ✅ API server connectivity debugging"
echo "   ✅ Port connectivity pre-checks"
echo "   ✅ CI-specific error handling"
echo "   ✅ Comprehensive troubleshooting documentation"
echo ""
echo -e "${BLUE}🚀 Next Steps:${NC}"
echo "   1. Test locally: ./examples/04-k8s-deployment/ocm-k8s-toolkit/deploy-example.sh"
echo "   2. Run full test suite: ./scripts/test-all.sh"
echo "   3. Monitor CI pipeline success rates"
echo "   4. Review error logs for improved debugging information"
