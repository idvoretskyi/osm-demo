#!/bin/bash

# Run all Kubernetes deployment OCM examples
# This script executes all examples in the 04-k8s-deployment section

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}☸️  Running all Kubernetes Deployment OCM Examples${NC}"
echo -e "${BLUE}===================================================${NC}"

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

# Check kubectl
if ! command -v kubectl > /dev/null 2>&1; then
    echo -e "${RED}❌ kubectl not found. Please install kubectl.${NC}"
    exit 1
fi

# Check kind
if ! command -v kind > /dev/null 2>&1; then
    echo -e "${RED}❌ kind not found. Please install kind.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"
echo ""

# Example 1: Setup Cluster
echo -e "${BLUE}🚀 Example 1: Setting up Kind Cluster${NC}"
echo -e "${BLUE}-----------------------------------${NC}"
cd "$SCRIPT_DIR"
./setup-cluster-enhanced.sh
echo ""

# Example 2: Deploy with OCM K8s Toolkit
echo -e "${BLUE}📦 Example 2: Deploy with OCM K8s Toolkit${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
cd "$SCRIPT_DIR/ocm-k8s-toolkit"
./deploy-example.sh
echo ""

# Summary
echo -e "${GREEN}🎉 All Kubernetes deployment examples completed successfully!${NC}"
echo -e "${BLUE}==========================================================${NC}"
echo ""
echo -e "${YELLOW}📚 What you've learned:${NC}"
echo "   ✅ Set up kind clusters for OCM development"
echo "   ✅ Installed OCM Custom Resource Definitions (CRDs)"
echo "   ✅ Deployed OCM components to Kubernetes"
echo "   ✅ Used OCM K8s Toolkit for component management"
echo "   ✅ Configured component repositories in Kubernetes"
echo ""
echo -e "${BLUE}🔗 Next steps:${NC}"
echo "   🚀 Explore advanced features: cd ../05-advanced"
echo "   📖 Check troubleshooting guide: ../../docs/troubleshooting.md"