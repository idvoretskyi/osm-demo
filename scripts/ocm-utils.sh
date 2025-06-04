#!/bin/bash

# Utility script for common OCM operations
# Provides convenient commands for managing OCM components and environments

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
    echo -e "${BLUE}OCM Demo Utilities${NC}"
    echo -e "${BLUE}==================${NC}"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo "  setup           - Run full environment setup"
    echo "  demo            - Run quick 5-minute demo tour"
    echo "  summary         - Show project overview and capabilities"
    echo "  registry        - Manage local OCI registry"
    echo "  cleanup         - Clean up demo artifacts"
    echo "  status          - Show environment status"
    echo "  run-all         - Run all examples in sequence"
    echo "  test-all        - Run comprehensive test suite"
    echo "  list-components - List components in local registry"
    echo ""
    echo -e "${YELLOW}Registry commands:${NC}"
    echo "  registry start  - Start local registry"
    echo "  registry stop   - Stop local registry"
    echo "  registry reset  - Reset registry (remove all data)"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  $0 setup"
    echo "  $0 demo"
    echo "  $0 registry start"
    echo "  $0 run-all"
    echo "  $0 test-all"
    echo "  $0 test-all --skip-k8s"
    echo "  $0 cleanup"
}

start_registry() {
    echo -e "${YELLOW}🐳 Starting local OCI registry...${NC}"
    
    if docker ps | grep -q local-registry; then
        echo -e "${GREEN}✅ Registry already running${NC}"
        return
    fi
    
    # Remove if exists but not running
    docker rm -f local-registry 2>/dev/null || true
    
    # Also clean up any conflicting containers on port 5001
    docker ps --filter "publish=5001" --format "{{.Names}}" | xargs -r docker stop 2>/dev/null || true
    docker ps -a --filter "publish=5001" --format "{{.Names}}" | xargs -r docker rm 2>/dev/null || true
    
    # Start registry
    if docker run -d -p 5001:5000 --name local-registry registry:2; then
        echo "Started registry container: local-registry"
        
        # Wait for registry to be ready with better error handling
        echo "Waiting for registry to be ready..."
        for i in {1..30}; do
            if curl -f -s -m 5 http://localhost:5001/v2/ >/dev/null 2>&1; then
                echo -e "${GREEN}✅ Registry started successfully on localhost:5001${NC}"
                return 0
            fi
            if [[ $i -eq 30 ]]; then
                echo -e "${RED}❌ Registry failed to start within 30 seconds${NC}"
                docker logs local-registry || true
                exit 1
            fi
            sleep 1
        done
    else
        echo -e "${RED}❌ Failed to start registry${NC}"
        exit 1
    fi
}

stop_registry() {
    echo -e "${YELLOW}🛑 Stopping local OCI registry...${NC}"
    docker stop local-registry 2>/dev/null || echo "Registry not running"
    docker rm local-registry 2>/dev/null || echo "Registry container not found"
    echo -e "${GREEN}✅ Registry stopped${NC}"
}

reset_registry() {
    echo -e "${YELLOW}🔄 Resetting local OCI registry...${NC}"
    stop_registry
    start_registry
    echo -e "${GREEN}✅ Registry reset complete${NC}"
}

check_status() {
    echo -e "${BLUE}📊 OCM Demo Environment Status${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
    
    # Check OCM CLI
    if command -v ocm &> /dev/null; then
        echo -e "${GREEN}✅ OCM CLI: $(ocm version --client 2>/dev/null | head -1 || echo 'installed')${NC}"
    else
        echo -e "${RED}❌ OCM CLI: Not installed${NC}"
    fi
    
    # Check Docker
    if command -v docker &> /dev/null && docker info &> /dev/null; then
        echo -e "${GREEN}✅ Docker: Running${NC}"
    else
        echo -e "${RED}❌ Docker: Not running${NC}"
    fi
    
    # Check registry
    if curl -s http://localhost:5001/v2/ > /dev/null; then
        echo -e "${GREEN}✅ Local Registry: Running on localhost:5001${NC}"
    else
        echo -e "${RED}❌ Local Registry: Not running${NC}"
    fi
    
    # Check kind
    if command -v kind &> /dev/null; then
        if kind get clusters | grep -q ocm-demo; then
            echo -e "${GREEN}✅ Kind Cluster: ocm-demo cluster exists${NC}"
        else
            echo -e "${YELLOW}⚠️  Kind: Installed but no ocm-demo cluster${NC}"
        fi
    else
        echo -e "${RED}❌ Kind: Not installed${NC}"
    fi
    
    # Check kubectl
    if command -v kubectl &> /dev/null; then
        if kubectl cluster-info &> /dev/null; then
            echo -e "${GREEN}✅ Kubectl: Connected to cluster${NC}"
        else
            echo -e "${YELLOW}⚠️  Kubectl: Installed but not connected${NC}"
        fi
    else
        echo -e "${RED}❌ Kubectl: Not installed${NC}"
    fi
    
    # Check Flux
    if command -v flux &> /dev/null; then
        echo -e "${GREEN}✅ Flux CLI: $(flux version --client 2>/dev/null | head -1 || echo 'installed')${NC}"
    else
        echo -e "${RED}❌ Flux CLI: Not installed${NC}"
    fi
}

list_components() {
    echo -e "${YELLOW}📦 Listing components in local registry...${NC}"
    
    # Start registry if not running
    if ! curl -s http://localhost:5001/v2/ > /dev/null; then
        echo -e "${YELLOW}⚠️  Local registry not running, starting it...${NC}"
        start_registry
    fi
    
    # Get repository list
    repos=$(curl -s http://localhost:5001/v2/_catalog | jq -r '.repositories[]?' 2>/dev/null || echo "")
    
    if [ -z "$repos" ]; then
        echo -e "${YELLOW}📭 No components found in registry${NC}"
        return
    fi
    
    echo -e "${GREEN}Components in localhost:5001:${NC}"
    echo "$repos" | while read -r repo; do
        if [[ "$repo" == *"ocm-demo"* ]]; then
            # Get tags for OCM components
            tags=$(curl -s "http://localhost:5001/v2/$repo/tags/list" | jq -r '.tags[]?' 2>/dev/null || echo "")
            if [ -n "$tags" ]; then
                echo "  📦 $repo"
                echo "$tags" | while read -r tag; do
                    echo "    🏷️  $tag"
                done
            fi
        fi
    done
}

run_all_examples() {
    echo -e "${BLUE}🚀 Running all OCM examples${NC}"
    echo -e "${BLUE}============================${NC}"
    echo ""
    
    # Check prerequisites
    check_status
    echo ""
    
    # Start registry if needed
    if ! curl -s http://localhost:5001/v2/ > /dev/null; then
        start_registry
    fi
    
    # Run basic examples
    echo -e "${YELLOW}📝 Running basic examples...${NC}"
    cd "$SCRIPT_DIR/examples/01-basic"
    ./run-examples.sh
    echo ""
    
    # Run transport examples
    echo -e "${YELLOW}🚀 Running transport examples...${NC}"
    cd "$SCRIPT_DIR/examples/02-transport/local-to-oci"
    ./transport-example.sh
    echo ""
    
    # Run signing examples
    echo -e "${YELLOW}🔐 Running signing examples...${NC}"
    cd "$SCRIPT_DIR/examples/03-signing/basic-signing"
    ./sign-component.sh
    echo ""
    
    echo -e "${GREEN}✨ All examples completed successfully!${NC}"
    echo ""
    list_components
}

cleanup_demo() {
    echo -e "${YELLOW}🧹 Cleaning up OCM demo environment...${NC}"
    
    # Stop and remove containers
    echo "Stopping containers..."
    docker stop local-registry demo-registry registry source-registry target-registry source-env-registry target-env-registry 2>/dev/null || true
    docker rm local-registry demo-registry registry source-registry target-registry source-env-registry target-env-registry 2>/dev/null || true
    
    # Delete kind cluster
    if kind get clusters | grep -q ocm-demo; then
        echo "Deleting kind cluster..."
        kind delete cluster --name ocm-demo
    fi
    
    # Clean up work directories
    echo "Cleaning up work directories..."
    find "$SCRIPT_DIR/examples" -name "work" -type d -exec rm -rf {} + 2>/dev/null || true
    
    echo -e "${GREEN}✅ Cleanup completed${NC}"
}

setup_environment() {
    echo -e "${YELLOW}🚀 Setting up OCM demo environment...${NC}"
    "$SCRIPT_DIR/setup-environment.sh"
}

run_test_suite() {
    echo -e "${YELLOW}🧪 Running comprehensive test suite...${NC}"
    "$SCRIPT_DIR/test-all.sh" "$@"
}

run_quick_demo() {
    echo -e "${YELLOW}🎬 Running quick demo tour...${NC}"
    "$SCRIPT_DIR/quick-demo.sh" "$@"
}

show_project_summary() {
    echo -e "${YELLOW}📊 Showing project summary...${NC}"
    "$SCRIPT_DIR/project-summary.sh" "$@"
}

# Main command processing
case "${1:-}" in
    "setup")
        setup_environment
        ;;
    "demo")
        shift
        run_quick_demo "$@"
        ;;
    "summary")
        shift
        show_project_summary "$@"
        ;;
    "registry")
        case "${2:-}" in
            "start")
                start_registry
                ;;
            "stop")
                stop_registry
                ;;
            "reset")
                reset_registry
                ;;
            *)
                echo -e "${RED}❌ Invalid registry command. Use: start, stop, or reset${NC}"
                exit 1
                ;;
        esac
        ;;
    "status")
        check_status
        ;;
    "list-components")
        list_components
        ;;
    "run-all")
        run_all_examples
        ;;
    "test-all")
        shift
        run_test_suite "$@"
        ;;
    "cleanup")
        cleanup_demo
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    "")
        show_help
        ;;
    *)
        echo -e "${RED}❌ Unknown command: $1${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac
