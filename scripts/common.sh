#!/bin/bash

# Common functions for OCM Demo Playground scripts
# Source this file in other scripts: source "$(dirname "$0")/common.sh"

# Get the directory of this script for sourcing libraries
readonly COMMON_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source modular libraries
source "$COMMON_LIB_DIR/lib/colors.sh"
source "$COMMON_LIB_DIR/lib/logging.sh"
source "$COMMON_LIB_DIR/lib/registry.sh"

# Default configuration variables
readonly DEFAULT_REGISTRY_PORT="${OCM_DEMO_REGISTRY_PORT:-5001}"
readonly DEFAULT_CLUSTER_NAME="${OCM_DEMO_CLUSTER_NAME:-ocm-demo}"
readonly DEFAULT_NAMESPACE="${OCM_DEMO_NAMESPACE:-ocm-demos}"
readonly DEFAULT_REGISTRY_NAME="${OCM_DEMO_REGISTRY_NAME:-local-registry}"

# Enhanced logging function for demos
log_demo() {
    echo -e "${COLOR_HEADER}🎬 $1${COLOR_RESET}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check OCM CLI prerequisite
check_ocm_cli() {
    if ! command_exists ocm; then
        log_error "OCM CLI not found" "Please run ./scripts/setup-environment.sh to install it"
        return 1
    fi
    return 0
}

# Check Docker prerequisite
check_docker() {
    if ! command_exists docker; then
        log_error "Docker not found" "Please install Docker first"
        return 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon not running" "Please start Docker"
        return 1
    fi
    
    return 0
}

# Registry functions are now provided by lib/registry.sh

# Create and clean work directory
setup_work_dir() {
    local work_dir="$1"
    
    log_info "Setting up work directory: $work_dir"
    
    rm -rf "$work_dir"
    mkdir -p "$work_dir"
    cd "$work_dir" || { log_error "Failed to change to work directory: $work_dir"; return 1; }
    
    log_success "Work directory ready"
}

# Cleanup function that can be used with trap
cleanup_on_exit() {
    local work_dir="${1:-}"
    
    log_info "Cleaning up on exit..."
    
    # Kill any background processes
    jobs -p | xargs -r kill 2>/dev/null || true
    
    # Clean up work directory if specified
    if [[ -n "$work_dir" && -d "$work_dir" ]]; then
        rm -rf "$work_dir" 2>/dev/null || true
    fi
    
    # Clean up temporary files
    rm -f /tmp/ocm-demo-* 2>/dev/null || true
}

# Check if we're in a CI environment
is_ci_environment() {
    [[ -n "${CI:-}" || -n "${GITHUB_ACTIONS:-}" || -n "${GITHUB_WORKFLOW:-}" ]]
}

# Get project root directory
get_project_root() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    
    # Try to find project root by looking for key files
    local current_dir="$script_dir"
    while [[ "$current_dir" != "/" ]]; do
        if [[ -f "$current_dir/README.md" && -d "$current_dir/scripts" && -d "$current_dir/examples" ]]; then
            echo "$current_dir"
            return 0
        fi
        current_dir="$(dirname "$current_dir")"
    done
    
    # Fallback to script directory parent
    dirname "$script_dir"
}

# Validate project structure
validate_project_structure() {
    local project_root="$1"
    
    local required_dirs="scripts examples docs"
    local required_files="README.md LICENSE"
    
    for dir in $required_dirs; do
        if [[ ! -d "$project_root/$dir" ]]; then
            log_error "Required directory missing: $dir"
            return 1
        fi
    done
    
    for file in $required_files; do
        if [[ ! -f "$project_root/$file" ]]; then
            log_warning "Expected file missing: $file"
        fi
    done
    
    return 0
}

# Check all prerequisites for OCM demo
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_tools=""
    local required_tools="ocm docker"
    
    for tool in $required_tools; do
        if ! command_exists "$tool"; then
            missing_tools="$missing_tools $tool"
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}" \
                  "Run ./scripts/setup-environment.sh to install missing tools"
        return 1
    fi
    
    # Check Docker daemon
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon not running" "Please start Docker"
        return 1
    fi
    
    log_success "All prerequisites available"
    return 0
}

# Print help for troubleshooting
show_troubleshooting_help() {
    echo -e "${COLOR_INFO}🔧 Troubleshooting Help${COLOR_RESET}"
    echo "======================"
    echo ""
    echo -e "${COLOR_WARNING}Common issues and solutions:${COLOR_RESET}"
    echo ""
    echo "1. OCM CLI not found:"
    echo "   - Run: ./scripts/setup-environment.sh"
    echo "   - Check: ocm version"
    echo ""
    echo "2. Docker not running:"
    echo "   - Start Docker Desktop"
    echo "   - Check: docker ps"
    echo ""
    echo "3. Registry connection issues:"
    echo "   - Check: curl http://localhost:5001/v2/"
    echo "   - Restart: ./scripts/ocm-utils.sh registry reset"
    echo ""
    echo "4. Permission issues:"
    echo "   - Fix: chmod +x script-name.sh"
    echo ""
    echo -e "${COLOR_INFO}For more help, see: docs/troubleshooting.md${COLOR_RESET}"
}