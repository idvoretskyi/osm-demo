#!/bin/bash

# Run all basic OCM examples
# This script executes all examples in the 01-basic section

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🎯 Running all Basic OCM Examples${NC}"
echo -e "${BLUE}======================================${NC}"

# Check prerequisites
echo -e "${YELLOW}🔍 Checking prerequisites...${NC}"

# Check OCM CLI
if ! command -v ocm &> /dev/null; then
    echo -e "${RED}❌ OCM CLI not found. Please run ../scripts/setup-environment.sh${NC}"
    exit 1
fi

# Check Docker
if ! command -v docker &> /dev/null; then
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

# Example 1: Hello World
echo -e "${BLUE}📝 Example 1: Hello World Component${NC}"
echo -e "${BLUE}----------------------------------${NC}"
cd "$SCRIPT_DIR/hello-world"
./create-component.sh
echo ""

# Example 2: Multi-Resource
echo -e "${BLUE}📦 Example 2: Multi-Resource Component${NC}"
echo -e "${BLUE}------------------------------------${NC}"
cd "$SCRIPT_DIR/multi-resource"
./create-component.sh
echo ""

# Summary
echo -e "${GREEN}🎉 All basic examples completed successfully!${NC}"
echo -e "${BLUE}=======================================${NC}"
echo ""
echo -e "${YELLOW}📚 What you've learned:${NC}"
echo "   ✅ Created basic OCM components"
echo "   ✅ Packaged multiple resources in components"
echo "   ✅ Used different access types (localBlob)"
echo "   ✅ Added metadata and labels"
echo "   ✅ Pushed components to OCI registry"
echo ""
echo -e "${BLUE}🔗 Next steps:${NC}"
echo "   📤 Try transport examples: cd ../02-transport"
echo "   🔐 Explore signing examples: cd ../03-signing"
echo "   ☸️  Deploy to Kubernetes: cd ../04-k8s-deployment"
