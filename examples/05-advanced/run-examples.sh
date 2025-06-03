#!/bin/bash

# Run all advanced examples
# This script executes all examples in the 05-advanced section

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Running all Advanced Examples${NC}"
echo -e "${BLUE}=================================${NC}"

# Check prerequisites
if ! command -v ocm &> /dev/null; then
    echo -e "${RED}❌ OCM CLI not found. Please install it first.${NC}"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker not found. Please install it first.${NC}"
    exit 1
fi

# Ensure registry is running
if ! curl -s http://localhost:5001/v2/ > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Starting local registry...${NC}"
    docker run -d -p 5001:5000 --name registry registry:2 || echo "Registry container already exists"
    sleep 3
fi

echo -e "${GREEN}✅ Prerequisites checked${NC}"

# Run component references example
echo -e "${YELLOW}📋 Running Component References Example${NC}"
cd "$SCRIPT_DIR/component-references"
./create-reference-example.sh
echo -e "${GREEN}✅ Component References Example completed${NC}"

echo ""

# Run localization example
echo -e "${YELLOW}🌍 Running Localization Example${NC}"
cd "$SCRIPT_DIR/localization"
./create-localization-example.sh
echo -e "${GREEN}✅ Localization Example completed${NC}"

echo ""
echo -e "${GREEN}🎉 All Advanced Examples completed successfully!${NC}"
echo -e "${BLUE}📚 Advanced concepts demonstrated:${NC}"
echo "   • Component References and Dependencies"
echo "   • Resource Localization and Customization"
echo "   • Complex Component Architectures"
echo "   • Advanced OCM Patterns"