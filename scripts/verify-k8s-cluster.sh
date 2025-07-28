#!/bin/bash

# K8s Cluster Verification Script
# This script verifies that a Kubernetes cluster is properly set up and accessible

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Kubernetes Cluster Verification${NC}"
echo "=================================="

# Function to check cluster readiness
verify_cluster() {
    local step=1
    
    # Step 1: Check kubectl availability
    echo -e "${YELLOW}Step $((step++)): Checking kubectl availability${NC}"
    if ! command -v kubectl > /dev/null 2>&1; then
        echo -e "${RED}❌ kubectl not found${NC}"
        return 1
    fi
    echo -e "${GREEN}✅ kubectl is available${NC}"
    
    # Step 2: Check kubectl configuration
    echo -e "${YELLOW}Step $((step++)): Checking kubectl configuration${NC}"
    if ! kubectl config current-context > /dev/null 2>&1; then
        echo -e "${RED}❌ No kubectl context available${NC}"
        echo "Available contexts:"
        kubectl config get-contexts 2>/dev/null || echo "No contexts found"
        return 1
    fi
    
    local current_context
    current_context=$(kubectl config current-context)
    echo -e "${GREEN}✅ Using kubectl context: $current_context${NC}"
    
    # Step 3: Check cluster connectivity
    echo -e "${YELLOW}Step $((step++)): Checking cluster connectivity${NC}"
    if ! kubectl cluster-info > /dev/null 2>&1; then
        echo -e "${RED}❌ Cannot connect to cluster${NC}"
        echo "Cluster info output:"
        kubectl cluster-info 2>&1 || echo "Failed to get cluster info"
        return 1
    fi
    echo -e "${GREEN}✅ Cluster is accessible${NC}"
    
    # Step 4: Check node readiness
    echo -e "${YELLOW}Step $((step++)): Checking node readiness${NC}"
    local nodes_output
    nodes_output=$(kubectl get nodes --no-headers 2>/dev/null || echo "")
    
    if [[ -z "$nodes_output" ]]; then
        echo -e "${RED}❌ No nodes found${NC}"
        return 1
    fi
    
    local ready_nodes
    ready_nodes=$(echo "$nodes_output" | grep -c " Ready " || echo "0")
    local total_nodes
    total_nodes=$(echo "$nodes_output" | wc -l | tr -d ' ')
    
    echo "Node status:"
    echo "$nodes_output"
    
    if [[ $ready_nodes -eq 0 ]]; then
        echo -e "${RED}❌ No ready nodes found (0/$total_nodes)${NC}"
        return 1
    fi
    echo -e "${GREEN}✅ Found $ready_nodes/$total_nodes ready node(s)${NC}"
    
    # Step 5: Check system pods
    echo -e "${YELLOW}Step $((step++)): Checking system pods${NC}"
    local pods_output
    pods_output=$(kubectl get pods -n kube-system --no-headers 2>/dev/null || echo "")
    
    if [[ -z "$pods_output" ]]; then
        echo -e "${YELLOW}⚠️  No system pods found or kube-system namespace not accessible${NC}"
    else
        local running_pods
        running_pods=$(echo "$pods_output" | grep -c " Running " || echo "0")
        local total_pods
        total_pods=$(echo "$pods_output" | wc -l | tr -d ' ')
        
        echo "System pod status (showing first 5):"
        echo "$pods_output" | head -5
        
        if [[ $running_pods -eq 0 ]]; then
            echo -e "${YELLOW}⚠️  No running system pods found (0/$total_pods)${NC}"
        else
            echo -e "${GREEN}✅ Found $running_pods/$total_pods running system pod(s)${NC}"
        fi
    fi
    
    # Step 6: Check for OCM CRDs (if applicable)
    echo -e "${YELLOW}Step $((step++)): Checking for OCM CRDs${NC}"
    local crd_count
    crd_count=$(kubectl get crd 2>/dev/null | grep -c "ocm.software" || echo "0")
    
    if [[ $crd_count -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  No OCM CRDs found${NC}"
    else
        echo -e "${GREEN}✅ Found $crd_count OCM CRD(s)${NC}"
    fi
    
    return 0
}

# Function to show debug information
show_debug_info() {
    echo -e "${BLUE}🐛 Debug Information${NC}"
    echo "===================="
    
    echo "Environment:"
    echo "  KUBECONFIG: ${KUBECONFIG:-$HOME/.kube/config}"
    echo "  Current directory: $(pwd)"
    USER_VAR="${USER:-$(whoami)}"
    echo "  USER: ${USER_VAR}"
    
    echo ""
    echo "Prerequisites check:"
    if command -v kind > /dev/null 2>&1; then
        echo "  ✅ kind is available: $(kind version | head -1)"
        echo ""
        echo "Available kind clusters:"
        kind get clusters 2>/dev/null || echo "  No kind clusters found"
    else
        echo "  ❌ kind is not installed"
        echo "     Install with: brew install kind (macOS) or see https://kind.sigs.k8s.io/docs/user/quick-start/"
    fi
    
    if command -v docker > /dev/null 2>&1; then
        echo "  ✅ Docker is available: $(docker --version)"
    else
        echo "  ❌ Docker is not available"
    fi
    
    if command -v kubectl > /dev/null 2>&1; then
        echo "  ✅ kubectl is available: $(kubectl version --client --short 2>/dev/null || echo 'version info unavailable')"
    else
        echo "  ❌ kubectl is not available"
    fi
    
    echo ""
    echo "Docker containers (filtered for kind):"
    docker ps --filter "name=kind" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "  Docker not available or no kind containers"
    
    echo ""
    echo "kubectl config:"
    kubectl config view --minify 2>/dev/null || echo "  kubectl config not available"
}

# Main execution
main() {
    if verify_cluster; then
        echo ""
        echo -e "${GREEN}🎉 Cluster verification PASSED${NC}"
        echo -e "${GREEN}   The Kubernetes cluster is ready for use${NC}"
        exit 0
    else
        echo ""
        echo -e "${RED}❌ Cluster verification FAILED${NC}"
        echo ""
        show_debug_info
        exit 1
    fi
}

# Show help if requested
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo "Usage: $0 [--help|-h]"
    echo ""
    echo "This script verifies that a Kubernetes cluster is properly set up and accessible."
    echo "It checks kubectl configuration, cluster connectivity, node readiness, and system pods."
    echo ""
    echo "Exit codes:"
    echo "  0 - Cluster is ready"
    echo "  1 - Cluster is not ready or not accessible"
    exit 0
fi

main "$@"
