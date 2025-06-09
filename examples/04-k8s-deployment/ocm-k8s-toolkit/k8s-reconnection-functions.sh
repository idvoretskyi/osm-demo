#!/bin/bash

# Enhanced Kubernetes Connectivity and Reconnection Functions
# Provides robust retry mechanisms and connection recovery for Kubernetes operations

# Handle connection refused errors with automatic recovery
handle_connection_refused() {
    local operation="$1"
    local attempt="$2"
    
    echo -e "${YELLOW}⚠️  Connection refused during $operation (attempt $attempt)${NC}"
    echo "🔄 Attempting automatic recovery..."
    
    # Check if kind cluster still exists
    if ! kind get clusters | grep -q ocm-demo; then
        echo -e "${RED}❌ Kind cluster 'ocm-demo' not found${NC}"
        return 1
    fi
    
    # Check Docker container status
    if ! docker ps | grep -q ocm-demo-control-plane; then
        echo -e "${RED}❌ Kind control plane container not running${NC}"
        return 1
    fi
    
    # Refresh kubeconfig
    echo "🔄 Refreshing kubeconfig..."
    if kind export kubeconfig --name ocm-demo; then
        echo -e "${GREEN}✅ Kubeconfig refreshed${NC}"
    else
        echo -e "${RED}❌ Failed to refresh kubeconfig${NC}"
        return 1
    fi
    
    # Wait for API server to be responsive
    local max_wait=60
    echo "⏳ Waiting for API server to become responsive..."
    
    local i=1
    while [ $i -le $max_wait ]; do
        if kubectl version --short > /dev/null 2>&1; then
            echo -e "${GREEN}✅ API server is responsive${NC}"
            return 0
        fi
        echo "   Waiting... ($i/${max_wait}s)"
        sleep 5
        i=$((i + 5))
    done
    
    echo -e "${RED}❌ API server not responsive after ${max_wait}s${NC}"
    return 1
}

# Smart kubectl command execution with automatic retry and connection recovery
smart_kubectl_with_retry() {
    local description="$1"
    local max_attempts="${2:-5}"
    shift 2
    # Store the command as a string for POSIX compatibility
    local kubectl_cmd="$*"
    
    echo -e "${BLUE}🔄 Executing: $description${NC}"
    
    for attempt in $(seq 1 $max_attempts); do
        echo "  Attempt $attempt/$max_attempts..."
        
        # Execute the kubectl command
        if eval "$kubectl_cmd" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ $description succeeded${NC}"
            return 0
        fi
        
        local exit_code=$?
        
        # Check if it's a connection refused error
        if eval "$kubectl_cmd" 2>&1 | grep -q "connection refused\|connection reset\|context deadline exceeded\|unable to connect"; then
            echo -e "${YELLOW}⚠️  Connection issue detected${NC}"
            
            if handle_connection_refused "$description" "$attempt"; then
                echo "🔄 Retrying after connection recovery..."
                continue
            else
                echo -e "${RED}❌ Connection recovery failed${NC}"
                return 1
            fi
        fi
        
        # For other errors, wait before retry
        if [ $attempt -lt $max_attempts ]; then
            local wait_time=$((attempt * 5))
            echo "   Command failed (exit code: $exit_code), waiting ${wait_time}s before retry..."
            sleep $wait_time
        fi
    done
    
    echo -e "${RED}❌ $description failed after $max_attempts attempts${NC}"
    return 1
}

# Ensure cluster connectivity with recovery attempts
ensure_cluster_connectivity() {
    echo -e "${BLUE}🔗 Ensuring cluster connectivity...${NC}"
    
    # First, basic connectivity check
    if kubectl version --short > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Basic connectivity confirmed${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}⚠️  No initial connectivity, attempting recovery...${NC}"
    
    # Try connection recovery
    if handle_connection_refused "connectivity check" "1"; then
        echo -e "${GREEN}✅ Connectivity restored${NC}"
        return 0
    fi
    
    echo -e "${RED}❌ Failed to establish cluster connectivity${NC}"
    return 1
}

# Validate cluster state with retry logic
validate_cluster_state() {
    echo -e "${BLUE}🏥 Validating cluster state...${NC}"
    
    # Check nodes are ready
    if ! smart_kubectl_with_retry "nodes ready check" 3 kubectl wait --for=condition=Ready nodes --all --timeout=60s; then
        echo -e "${RED}❌ Nodes not ready${NC}"
        return 1
    fi
    
    # Check system pods are running  
    if ! smart_kubectl_with_retry "system pods check" 3 kubectl get pods -n kube-system; then
        echo -e "${RED}❌ Cannot query system pods${NC}"
        return 1
    fi
    
    # Check for any failing system pods
    local failing_pods
    failing_pods=$(kubectl get pods -n kube-system --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l || echo "0")
    
    if [ "$failing_pods" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  $failing_pods system pods not running${NC}"
        kubectl get pods -n kube-system --field-selector=status.phase!=Running
    else
        echo -e "${GREEN}✅ All system pods running${NC}"
    fi
    
    echo -e "${GREEN}✅ Cluster state validation completed${NC}"
    return 0
}

# Safe apply manifests with connection retry
safe_apply_manifests() {
    local manifest_dir="$1"
    local description="$2"
    
    echo -e "${BLUE}📋 Applying manifests: $description${NC}"
    
    if [ ! -d "$manifest_dir" ]; then
        echo -e "${RED}❌ Manifest directory not found: $manifest_dir${NC}"
        return 1
    fi
    
    # Apply each manifest file with retry
    local failed_files=""
    find "$manifest_dir" -name "*.yaml" -o -name "*.yml" | sort | while read -r manifest_file; do
        local filename=$(basename "$manifest_file")
        
        if smart_kubectl_with_retry "applying $filename" 5 kubectl apply -f "$manifest_file"; then
            echo -e "${GREEN}✅ Applied: $filename${NC}"
        else
            echo -e "${RED}❌ Failed to apply: $filename${NC}"
            if [ -z "$failed_files" ]; then
                failed_files="$filename"
            else
                failed_files="$failed_files $filename"
            fi
        fi
        
        # Small delay between applications to avoid overwhelming the API server
        sleep 2
    done
    
    if [ -z "$failed_files" ]; then
        echo -e "${GREEN}✅ All manifests applied successfully${NC}"
        return 0
    else
        local failed_count
        failed_count=$(echo "$failed_files" | wc -w | tr -d ' ')
        echo -e "${RED}❌ Failed to apply $failed_count manifests: $failed_files${NC}"
        return 1
    fi
}

# Wait for deployment with connection retry
wait_for_deployment_ready() {
    local namespace="$1"
    local deployment="$2"
    local timeout="${3:-300}"
    
    echo -e "${YELLOW}⏳ Waiting for deployment '$deployment' in namespace '$namespace' to be ready...${NC}"
    
    if smart_kubectl_with_retry "wait for deployment $deployment" 3 kubectl wait --for=condition=Available deployment/"$deployment" -n "$namespace" --timeout="${timeout}s"; then
        echo -e "${GREEN}✅ Deployment '$deployment' is ready${NC}"
        return 0
    else
        echo -e "${RED}❌ Deployment '$deployment' failed to become ready${NC}"
        
        # Show debug information
        echo -e "${YELLOW}📊 Debug information:${NC}"
        smart_kubectl_with_retry "get deployment status" 2 kubectl get deployment "$deployment" -n "$namespace" -o wide || true
        smart_kubectl_with_retry "describe deployment" 2 kubectl describe deployment "$deployment" -n "$namespace" || true
        smart_kubectl_with_retry "get pods" 2 kubectl get pods -n "$namespace" -l "app=$deployment" || true
        
        return 1
    fi
}

# Enhanced cleanup with connection retry
enhanced_cleanup() {
    echo -e "${YELLOW}🧹 Performing enhanced cleanup...${NC}"
    
    # Remove any stuck finalizers if possible
    if ensure_cluster_connectivity; then
        echo "🔄 Cleaning up OCM resources..."
        
        # Remove OCM configurations first
        smart_kubectl_with_retry "delete OCM configurations" 2 kubectl delete ocmconfigurations --all -n ocm-demos --ignore-not-found=true --timeout=60s || true
        
        # Remove component versions
        smart_kubectl_with_retry "delete component versions" 2 kubectl delete componentversions --all -n ocm-demos --ignore-not-found=true --timeout=60s || true
        
        # Clean up any stuck pods
        smart_kubectl_with_retry "delete stuck pods" 2 kubectl delete pods --all -n ocm-demos --force --grace-period=0 --ignore-not-found=true || true
        
        echo -e "${GREEN}✅ Enhanced cleanup completed${NC}"
    else
        echo -e "${YELLOW}⚠️  Cannot connect to cluster for cleanup${NC}"
    fi
}

# Enhanced error handler with connection recovery
enhanced_error_handler() {
    local exit_code=$?
    echo -e "${RED}❌ Error detected (exit code: $exit_code)${NC}"
    
    # Try to gather debug information if we can connect
    if ensure_cluster_connectivity; then
        echo -e "${YELLOW}📊 Gathering debug information...${NC}"
        
        echo "=== Cluster Status ==="
        smart_kubectl_with_retry "get nodes" 2 kubectl get nodes || echo "Cannot get nodes"
        
        echo "=== OCM Demos Namespace ==="
        smart_kubectl_with_retry "get all in ocm-demos" 2 kubectl get all -n ocm-demos || echo "Cannot get resources in ocm-demos"
        
        echo "=== Recent Events ==="
        smart_kubectl_with_retry "get events" 2 kubectl get events -n ocm-demos --sort-by='.metadata.creationTimestamp' | tail -10 || echo "Cannot get events"
    fi
    
    enhanced_cleanup
    exit $exit_code
}

# Detect CI environment for special handling
detect_ci_environment() {
    if [[ -n "${CI:-}" || -n "${GITHUB_ACTIONS:-}" || -n "${JENKINS_URL:-}" || -n "${TRAVIS:-}" ]]; then
        return 0  # true
    else
        return 1  # false
    fi
}

# CI-specific stability measures
apply_ci_stability_measures() {
    if detect_ci_environment; then
        echo -e "${BLUE}🤖 Applying CI-specific stability measures...${NC}"
        
        # Extra wait for CI environments
        echo "⏳ Extra stabilization wait for CI environment..."
        sleep 10
        
        # Verify critical components are stable
        echo "🔍 Verifying critical components in CI..."
        
        # Check API server responsiveness multiple times
        for i in {1..3}; do
            if ! kubectl version --short > /dev/null 2>&1; then
                echo "⚠️  API server check $i/3 failed, waiting..."
                sleep 10
            else
                echo "✅ API server check $i/3 passed"
            fi
        done
        
        echo -e "${GREEN}✅ CI stability measures applied${NC}"
    fi
}

echo -e "${GREEN}✅ Enhanced Kubernetes connectivity functions loaded${NC}"
