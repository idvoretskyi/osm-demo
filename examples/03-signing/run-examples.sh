#!/bin/bash

# Run all signing OCM examples
# This script executes all examples in the 03-signing section

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔐 Running all Signing OCM Examples${NC}"
echo -e "${BLUE}====================================${NC}"

# Check prerequisites
echo -e "${YELLOW}🔍 Checking prerequisites...${NC}"

# Check OCM CLI
if ! command -v ocm > /dev/null 2>&1; then
    echo -e "${RED}❌ OCM CLI not found. Please run ../../scripts/setup-environment.sh${NC}"
    exit 1
fi

# Check Docker
if ! command -v docker > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker not found. Please install Docker.${NC}"
    exit 1
fi

# Start local registry if not running
if ! curl -s http://localhost:5001/v2/ > /dev/null 2>&1; then
    echo -e "${YELLOW}🚀 Starting local OCI registry...${NC}"
    # Remove any existing registry containers that might conflict
    docker rm -f registry local-registry 2>/dev/null || true
    docker run -d -p 5001:5000 --name local-registry registry:2
    sleep 3
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"
echo ""

# Example 1: Basic Signing
echo -e "${BLUE}🔏 Example 1: Basic Component Signing${NC}"
echo -e "${BLUE}------------------------------------${NC}"
cd "$SCRIPT_DIR/basic-signing"
./sign-component.sh
echo ""

# Summary
echo -e "${GREEN}🎉 All signing examples completed successfully!${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""
echo -e "${YELLOW}📚 What you've learned:${NC}"
echo "   ✅ Generated RSA key pairs for signing"
echo "   ✅ Signed OCM components with digital signatures"
echo "   ✅ Verified component signatures"
echo "   ✅ Used OCM normalization for secure signing"
echo ""
echo -e "${BLUE}🔗 Next steps:${NC}"
echo "   ☸️  Deploy signed components: cd ../04-k8s-deployment"
echo "   🚀 Explore advanced features: cd ../05-advanced"