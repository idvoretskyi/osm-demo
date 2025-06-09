#!/bin/bash

# Run all transport examples
# This script executes all examples in the 02-transport section

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Running all Transport Examples${NC}"
echo -e "${BLUE}==================================${NC}"

# Check prerequisites
echo -e "${YELLOW}🔍 Checking prerequisites...${NC}"

if ! command -v ocm > /dev/null 2>&1; then
    echo -e "${RED}❌ OCM CLI not found. Please run ../scripts/setup-environment.sh${NC}"
    exit 1
fi

if ! command -v docker > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker not found. Please install Docker.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"
echo ""

# Example 1: Local to OCI Transport
echo -e "${BLUE}🚀 Example 1: Local to OCI Transport${NC}"
echo -e "${BLUE}-----------------------------------${NC}"
cd "$SCRIPT_DIR/local-to-oci"
./transport-example.sh
echo ""

# Example 2: Offline Transport
echo -e "${BLUE}🔒 Example 2: Offline Transport (Air-Gapped)${NC}"
echo -e "${BLUE}-------------------------------------------${NC}"
cd "$SCRIPT_DIR/offline-transport"
./offline-example.sh
echo ""

# Summary
echo -e "${GREEN}🎉 All transport examples completed successfully!${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${YELLOW}📚 What you've learned:${NC}"
echo "   ✅ Transported components between local archives and OCI registries"
echo "   ✅ Performed cross-registry replication"
echo "   ✅ Demonstrated air-gapped transport with Common Transport Format"
echo "   ✅ Verified component integrity across transport operations"
echo ""
echo -e "${BLUE}🔗 Next steps:${NC}"
echo "   🔐 Try signing examples: cd ../03-signing"
echo "   ☸️  Deploy to Kubernetes: cd ../04-k8s-deployment"
echo "   🛠️  Use utilities: ../../scripts/ocm-utils.sh list-components"
