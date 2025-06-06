#!/bin/bash

# Common functions for OCM Demo Playground scripts
# Source this file in other scripts: source "$(dirname "$0")/common.sh"

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Logging functions
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
    echo -e "${RED}❌ ERROR: $1${NC}" >&2
    if [[ -n "${2:-}" ]]; then
        echo -e "${YELLOW}💡 HINT: $2${NC}" >&2
    fi
}

log_step() {
    echo -e "${CYAN}🔹 $1${NC}"
}

log_demo() {
    echo -e "${PURPLE}🎬 $1${NC}"
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

# Registry management functions
start_registry() {
    local port="${1:-5001}"
    local name="${2:-local-registry}"
    
    log_info "Starting registry on port $port..."
    
    # Check if already running
    if docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
        log_success "Registry already running"
        return 0
    fi
    
    # Clean up any existing containers on the port
    cleanup_registry_port "$port"
    
    # Remove existing container with same name
    docker rm -f "$name" 2>/dev/null || true
    
    # Start new registry
    if docker run -d -p "${port}:5000" --name "$name" registry:2; then
        log_info "Waiting for registry to be ready..."
        
        # Wait for registry to be ready
        for i in {1..30}; do
            if curl -f -s -m 5 "http://localhost:${port}/v2/" >/dev/null 2>&1; then
                log_success "Registry ready on localhost:${port}"
                return 0
            fi
            
            if [[ $i -eq 30 ]]; then
                log_error "Registry failed to start within 30 seconds"
                docker logs "$name" || true
                return 1
            fi
            sleep 1
        done
    else
        log_error "Failed to start registry container"
        return 1
    fi
}

# Clean up containers using a specific port
cleanup_registry_port() {
    local port="$1"
    
    log_info "Cleaning up containers on port $port..."
    
    # Stop and remove containers using the port
    docker ps --filter "publish=${port}" --format "{{.Names}}" 2>/dev/null | \
        xargs -r docker stop 2>/dev/null || true
    docker ps -a --filter "publish=${port}" --format "{{.Names}}" 2>/dev/null | \
        xargs -r docker rm 2>/dev/null || true
}

# Clean up all registry containers
cleanup_all_registries() {
    log_info "Cleaning up all registry containers..."
    
    # Common registry names
    local registry_names=(
        "registry" "local-registry" "source-registry" "target-registry"
        "source-env-registry" "target-env-registry" "demo-registry"
    )
    
    for name in "${registry_names[@]}"; do
        docker rm -f "$name" 2>/dev/null || true
    done
    
    # Clean up registry containers by image
    docker ps -a --filter "ancestor=registry:2" --format "{{.Names}}" 2>/dev/null | \
        xargs -r docker rm -f 2>/dev/null || true
    
    # Clean up common ports
    for port in 5001 5002 5003 5004; do
        cleanup_registry_port "$port"
    done
    
    log_success "Registry cleanup complete"
}

# Test registry connectivity
test_registry() {
    local url="$1"
    local timeout="${2:-5}"
    
    if curl -f -s -m "$timeout" "${url}/v2/" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Wait for registry to be ready
wait_for_registry() {
    local url="$1"
    local timeout="${2:-30}"
    
    log_info "Waiting for registry at $url to be ready..."
    
    for i in $(seq 1 "$timeout"); do
        if test_registry "$url"; then
            log_success "Registry at $url is ready"
            return 0
        fi
        
        if [[ $((i % 5)) -eq 0 ]]; then
            log_info "Still waiting... ($i/$timeout seconds)"
        fi
        sleep 1
    done
    
    log_error "Registry at $url failed to become ready within $timeout seconds"
    return 1
}

# Create and clean work directory
setup_work_dir() {
    local work_dir="$1"
    
    log_info "Setting up work directory: $work_dir"
    
    rm -rf "$work_dir"
    mkdir -p "$work_dir"
    cd "$work_dir"
    
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
    
    local required_dirs=("scripts" "examples" "docs")
    local required_files=("README.md" "LICENSE")
    
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$project_root/$dir" ]]; then
            log_error "Required directory missing: $dir"
            return 1
        fi
    done
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$project_root/$file" ]]; then
            log_warning "Expected file missing: $file"
        fi
    done
    
    return 0
}

# Check all prerequisites for OCM demo
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_tools=()
    local required_tools=("ocm" "docker")
    
    for tool in "${required_tools[@]}"; do
        if ! command_exists "$tool"; then
            missing_tools+=("$tool")
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
    echo -e "${BLUE}🔧 Troubleshooting Help${NC}"
    echo "======================"
    echo ""
    echo -e "${YELLOW}Common issues and solutions:${NC}"
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
    echo -e "${BLUE}For more help, see: docs/troubleshooting.md${NC}"
}