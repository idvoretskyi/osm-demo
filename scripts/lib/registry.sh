#!/usr/bin/env bash

# Registry management functions
# Requires logging.sh to be sourced first

readonly REGISTRY_IMAGE="registry:2"
readonly DEFAULT_REGISTRY_TIMEOUT=30

start_registry() {
    local port="${1:-5001}"
    local name="${2:-local-registry}"
    local timeout="${3:-$DEFAULT_REGISTRY_TIMEOUT}"
    
    log_info "Starting registry '$name' on port $port..."
    
    # Check if already running
    if docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
        log_success "Registry '$name' already running"
        return 0
    fi
    
    # Clean up any existing containers on the port
    cleanup_registry_port "$port"
    
    # Remove existing container with same name
    docker rm -f "$name" 2>/dev/null || true
    
    # Start new registry
    if docker run -d -p "${port}:5000" --name "$name" "$REGISTRY_IMAGE"; then
        wait_for_registry "http://localhost:${port}" "$timeout"
    else
        log_error "Failed to start registry container '$name'"
        return 1
    fi
}

cleanup_registry_port() {
    local port="$1"
    
    log_info "Cleaning up containers on port $port..."
    
    # Stop and remove containers using the port
    docker ps --filter "publish=${port}" --format "{{.Names}}" 2>/dev/null | \
        xargs -r docker stop 2>/dev/null || true
    docker ps -a --filter "publish=${port}" --format "{{.Names}}" 2>/dev/null | \
        xargs -r docker rm 2>/dev/null || true
}

cleanup_all_registries() {
    log_info "Cleaning up all registry containers..."
    
    # Common registry names
    local registry_names="registry local-registry source-registry target-registry source-env-registry target-env-registry demo-registry"
    
    for name in $registry_names; do
        docker rm -f "$name" 2>/dev/null || true
    done
    
    # Clean up registry containers by image
    docker ps -a --filter "ancestor=$REGISTRY_IMAGE" --format "{{.Names}}" 2>/dev/null | \
        xargs -r docker rm -f 2>/dev/null || true
    
    # Clean up common ports
    for port in 5001 5002 5003 5004; do
        cleanup_registry_port "$port"
    done
    
    log_success "Registry cleanup complete"
}

test_registry() {
    local url="$1"
    local timeout="${2:-5}"
    
    curl -f -s -m "$timeout" "${url}/v2/" >/dev/null 2>&1
}

wait_for_registry() {
    local url="$1"
    local timeout="${2:-$DEFAULT_REGISTRY_TIMEOUT}"
    
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

stop_registry() {
    local name="$1"
    
    if docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
        log_info "Stopping registry '$name'..."
        docker stop "$name" >/dev/null
        docker rm "$name" >/dev/null
        log_success "Registry '$name' stopped"
    else
        log_info "Registry '$name' not running"
    fi
}

restart_registry() {
    local port="${1:-5001}"
    local name="${2:-local-registry}"
    
    stop_registry "$name"
    start_registry "$port" "$name"
}