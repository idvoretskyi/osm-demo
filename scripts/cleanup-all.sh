#!/bin/bash

# OCM Demo Playground - Complete Cleanup Script
# Removes all previously deployed resources including Docker containers, 
# Kubernetes clusters, OCM components, and temporary files.

set -euo pipefail

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly NC='\033[0m'

# Configuration
SCRIPT_DIR=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

PROJECT_ROOT=""
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly PROJECT_ROOT

# Include common libraries
# shellcheck source=./lib/logging.sh
if [[ -f "$SCRIPT_DIR/lib/logging.sh" ]]; then
    source "$SCRIPT_DIR/lib/logging.sh"
fi

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_section() {
    echo -e "${PURPLE}🧹 $1${NC}"
}

# Cleanup counters
CLEANUP_ACTIONS=0
SUCCESSFUL_CLEANUPS=0
FAILED_CLEANUPS=0

increment_cleanup() {
    ((CLEANUP_ACTIONS++))
}

increment_success() {
    ((SUCCESSFUL_CLEANUPS++))
}

increment_failure() {
    ((FAILED_CLEANUPS++))
}

# Safe cleanup function with error handling
safe_cleanup() {
    local description="$1"
    local command="$2"
    local ignore_errors="${3:-false}"
    
    increment_cleanup
    log_info "Cleaning up: $description"
    
    if eval "$command" 2>/dev/null; then
        log_success "$description cleaned up successfully"
        increment_success
        return 0
    else
        if [[ "$ignore_errors" == "true" ]]; then
            log_warning "$description cleanup failed (ignored)"
            increment_success
            return 0
        else
            log_error "$description cleanup failed"
            increment_failure
            return 1
        fi
    fi
}

# Cleanup Docker containers and networks
cleanup_docker_resources() {
    log_section "Docker Resources Cleanup"
    
    # Stop and remove OCM demo related containers
    local containers=(
        "local-registry"
        "demo-registry"
        "source-env-registry"
        "target-env-registry" 
        "k8s-demo-registry"
        "ocm-demo-registry"
    )
    
    for container in "${containers[@]}"; do
        if docker ps -a --format "table {{.Names}}" | grep -q "^${container}$" 2>/dev/null; then
            safe_cleanup "Docker container: $container" \
                "docker stop '$container' && docker rm '$container'" true
        fi
    done
    
    # Remove any remaining containers with OCM demo labels/names
    safe_cleanup "OCM demo containers (by pattern)" \
        "docker ps -a --format 'table {{.Names}}' | grep -E '(ocm|demo|registry)' | xargs -r docker rm -f" true
    
    # Remove unused networks
    safe_cleanup "Docker networks cleanup" \
        "docker network prune -f" true
    
    # Remove unused volumes
    safe_cleanup "Docker volumes cleanup" \
        "docker volume prune -f" true
    
    # Clean up dangling images
    safe_cleanup "Docker images cleanup" \
        "docker image prune -f" true
}

# Cleanup Kubernetes clusters
cleanup_kubernetes_clusters() {
    log_section "Kubernetes Clusters Cleanup"
    
    # Check if kind is available
    if ! command -v kind >/dev/null 2>&1; then
        log_warning "kind not available, skipping cluster cleanup"
        return 0
    fi
    
    # Remove OCM demo clusters
    local clusters=(
        "ocm-demo"
        "kind"
        "ocm-demo-cluster"
        "demo-cluster"
    )
    
    for cluster in "${clusters[@]}"; do
        if kind get clusters 2>/dev/null | grep -q "^${cluster}$"; then
            safe_cleanup "Kind cluster: $cluster" \
                "kind delete cluster --name '$cluster'" true
        fi
    done
    
    # Remove any remaining kind clusters (with confirmation for safety)
    local remaining_clusters
    remaining_clusters=$(kind get clusters 2>/dev/null || true)
    if [[ -n "$remaining_clusters" ]]; then
        log_warning "Additional kind clusters found: $remaining_clusters"
        log_info "These were not automatically removed for safety"
        log_info "Remove manually with: kind delete cluster --name <cluster-name>"
    fi
}

# Cleanup OCM components and archives
cleanup_ocm_components() {
    log_section "OCM Components Cleanup"
    
    # Check if OCM CLI is available
    if ! command -v ocm >/dev/null 2>&1; then
        log_warning "OCM CLI not available, skipping component cleanup"
        return 0
    fi
    
    # Remove OCM workspace and cache
    safe_cleanup "OCM workspace" \
        "rm -rf ~/.ocm" true
    
    # Clean up component archives in project
    safe_cleanup "OCM component archives" \
        "find '$PROJECT_ROOT' -name '*.ocm' -type f -delete" true
    
    # Clean up transport archives
    safe_cleanup "OCM transport archives" \
        "find '$PROJECT_ROOT' -name '*.ctf' -type d -exec rm -rf {} + 2>/dev/null || true" true
    
    # Clean up extracted manifests
    safe_cleanup "Extracted manifests" \
        "find '$PROJECT_ROOT' -name 'extracted' -type d -exec rm -rf {} + 2>/dev/null || true" true
}

# Cleanup temporary files and directories
cleanup_temporary_files() {
    log_section "Temporary Files Cleanup"
    
    # Remove demo-specific temporary files
    safe_cleanup "Demo temporary files" \
        "find '$PROJECT_ROOT' -name 'demo-*.tmp' -delete" true
    
    # Remove signing keys (demo keys only)
    safe_cleanup "Demo signing keys" \
        "find '$PROJECT_ROOT' -name 'demo*.key' -o -name 'demo*.pub' | xargs rm -f" true
    
    # Remove log files
    safe_cleanup "Log files" \
        "find '$PROJECT_ROOT' -name '*.log' -delete" true
    
    # Clean up test artifacts
    safe_cleanup "Test artifacts" \
        "rm -rf '$PROJECT_ROOT'/test-results '$PROJECT_ROOT'/.pytest_cache" true
    
    # Remove Python cache
    safe_cleanup "Python cache files" \
        "find '$PROJECT_ROOT' -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true" true
    
    # Remove Python egg-info
    safe_cleanup "Python egg-info directories" \
        "find '$PROJECT_ROOT' -name '*.egg-info' -type d -exec rm -rf {} + 2>/dev/null || true" true
}

# Cleanup configuration and state files
cleanup_configuration_files() {
    log_section "Configuration Files Cleanup"
    
    # Remove Terraform state files (be careful here!)
    if [[ -f "$PROJECT_ROOT/terraform.tfstate" ]]; then
        log_warning "Found terraform.tfstate - manual review recommended"
        log_info "Remove with: rm $PROJECT_ROOT/terraform.tfstate"
    fi
    
    # Remove kubeconfig context for demo clusters
    if command -v kubectl >/dev/null 2>&1; then
        safe_cleanup "Kubectl demo contexts" \
            "kubectl config delete-context kind-ocm-demo 2>/dev/null || true && kubectl config delete-context kind-demo-cluster 2>/dev/null || true" true
    fi
}

# Reset environment to clean state
reset_environment() {
    log_section "Environment Reset"
    
    # Stop any running registries
    safe_cleanup "Local registries" \
        "docker ps --filter 'name=registry' --format '{{.Names}}' | xargs -r docker stop" true
    
    # Clean up any background processes
    safe_cleanup "Background processes cleanup" \
        "pkill -f 'ocm.*demo' || true" true
}

# Show help information
show_help() {
    echo -e "${BLUE}OCM Demo Playground - Complete Cleanup${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo "  --help, -h          Show this help message"
    echo "  --dry-run           Show what would be cleaned up without doing it"
    echo "  --docker-only       Clean up only Docker resources"
    echo "  --k8s-only          Clean up only Kubernetes resources"
    echo "  --files-only        Clean up only files and directories"
    echo "  --all               Clean up everything (default)"
    echo "  --force             Skip confirmation prompts"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  $0                  # Interactive cleanup of all resources"
    echo "  $0 --dry-run        # Show what would be cleaned up"
    echo "  $0 --docker-only    # Clean up only Docker containers and images"
    echo "  $0 --force          # Skip confirmation and clean everything"
    echo ""
}

# Main cleanup orchestration
main() {
    local dry_run=false
    local docker_only=false
    local k8s_only=false
    local files_only=false
    local force=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --docker-only)
                docker_only=true
                shift
                ;;
            --k8s-only)
                k8s_only=true
                shift
                ;;
            --files-only)
                files_only=true
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            --all)
                # Default behavior, explicitly set
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    if [[ "$dry_run" == "true" ]]; then
        log_info "DRY RUN MODE - No actual cleanup will be performed"
        echo ""
    fi
    
    echo -e "${PURPLE}🧹 OCM Demo Playground - Complete Cleanup${NC}"
    echo -e "${PURPLE}===========================================${NC}"
    echo ""
    
    # Confirmation (unless forced)
    if [[ "$force" != "true" && "$dry_run" != "true" ]]; then
        echo -e "${YELLOW}This will remove:${NC}"
        echo "  • Docker containers and images"
        echo "  • Kubernetes clusters (kind)"
        echo "  • OCM components and archives"
        echo "  • Temporary files and directories"
        echo "  • Configuration and state files"
        echo ""
        read -p "Are you sure you want to continue? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Cleanup cancelled by user"
            exit 0
        fi
        echo ""
    fi
    
    local start_time
    start_time=$(date +%s)
    
    # Execute cleanup based on options
    if [[ "$docker_only" == "true" ]]; then
        cleanup_docker_resources
    elif [[ "$k8s_only" == "true" ]]; then
        cleanup_kubernetes_clusters
    elif [[ "$files_only" == "true" ]]; then
        cleanup_temporary_files
        cleanup_configuration_files
    else
        # Default: clean everything
        cleanup_docker_resources
        cleanup_kubernetes_clusters
        cleanup_ocm_components
        cleanup_temporary_files
        cleanup_configuration_files
        reset_environment
    fi
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Summary
    echo ""
    echo -e "${PURPLE}🧹 Cleanup Summary${NC}"
    echo -e "${PURPLE}=================${NC}"
    echo "  Total cleanup actions: $CLEANUP_ACTIONS"
    echo "  Successful cleanups: $SUCCESSFUL_CLEANUPS"
    echo "  Failed cleanups: $FAILED_CLEANUPS"
    echo "  Duration: ${duration}s"
    echo ""
    
    if [[ $FAILED_CLEANUPS -eq 0 ]]; then
        log_success "All cleanup operations completed successfully!"
        
        if [[ "$dry_run" != "true" ]]; then
            echo ""
            echo -e "${GREEN}🎉 Environment is now clean and ready for fresh demos!${NC}"
            echo ""
            echo -e "${BLUE}Next steps:${NC}"
            echo "  • Run './scripts/setup-environment.sh' to set up the environment"
            echo "  • Run './scripts/quick-demo.sh' to start a fresh demo"
            echo "  • Run 'make demo' for a quick start"
        fi
    else
        log_warning "Some cleanup operations failed. Manual intervention may be required."
        exit 1
    fi
}

# Execute main function
main "$@"