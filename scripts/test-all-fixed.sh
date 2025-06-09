#!/bin/bash
set -euo pipefail

# OCM Demo Playground - Test All Examples
# This script runs all examples in sequence to validate the complete workflow

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

readonly TEST_LOG="/tmp/ocm-demo-test.log"

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

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

log_test() {
    echo -e "${PURPLE}🧪 $1${NC}"
}

# Generate unique container name to avoid conflicts
generate_container_name() {
    local base_name="$1"
    local timestamp
    local random_suffix
    timestamp=$(date +%s)
    random_suffix=$(od -An -N2 -tx1 /dev/urandom | tr -d ' ')
    echo "${base_name}-${timestamp}-${random_suffix}"
}

# Enhanced registry cleanup
cleanup_registry_containers() {
    log_info "Cleaning up registry containers..."
    
    # Stop and remove all registry containers
    docker ps -a --filter "ancestor=registry:2" --format "{{.Names}}" 2>/dev/null | \
        xargs -r docker rm -f 2>/dev/null || true
    
    # Clean up containers with common registry names
    for name in registry local-registry source-registry target-registry source-env-registry target-env-registry; do
        docker rm -f "$name" 2>/dev/null || true
    done
    
    # Clean up containers using registry ports
    for port in 5001 5002 5003 5004; do
        docker ps --filter "publish=$port" --format "{{.Names}}" 2>/dev/null | \
            xargs -r docker stop 2>/dev/null || true
        docker ps -a --filter "publish=$port" --format "{{.Names}}" 2>/dev/null | \
            xargs -r docker rm 2>/dev/null || true
    done
    
    log_success "Registry cleanup complete"
}

# Comprehensive cleanup function
cleanup() {
    local force_cleanup="${1:-false}"
    
    log_info "Starting cleanup process..."
    
    if [[ "$force_cleanup" == "true" ]]; then
        log_warning "Force cleanup mode - removing all OCM-related containers and volumes"
        
        # Stop and remove all registry containers
        cleanup_registry_containers
        
        # Stop and remove kind clusters
        kind get clusters 2>/dev/null | grep -E "(ocm|demo)" | \
            xargs -r -I {} kind delete cluster --name {} 2>/dev/null || true
        
        # Clean up volumes
        docker volume ls --filter "name=ocm" --format "{{.Name}}" | \
            xargs -r docker volume rm 2>/dev/null || true
        docker volume ls --filter "name=demo" --format "{{.Name}}" | \
            xargs -r docker volume rm 2>/dev/null || true
        
        # Clean up networks
        docker network ls --filter "name=kind" --format "{{.Name}}" | \
            xargs -r docker network rm 2>/dev/null || true
        
        log_success "Force cleanup completed"
    else
        log_info "Standard cleanup mode"
        cleanup_registry_containers
        
        # Clean up test files
        rm -f /tmp/ocm-test-*.log 2>/dev/null || true
        
        # Clean up work directories from failed tests
        find "$PROJECT_ROOT/examples" -name "work" -type d -exec rm -rf {} + 2>/dev/null || true
    fi
    
    log_success "Cleanup process completed"
}

# Test runner function
run_test() {
    local test_name="$1"
    local test_command="$2"
    local working_dir="${3:-$PROJECT_ROOT}"
    local timeout="${4:-300}"  # Default 5 minutes timeout
    local retry_count="${5:-1}"  # Default 1 attempt
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "Running test: $test_name"
    
    local start_time
    local test_log_file="/tmp/ocm-test-${test_name//[^a-zA-Z0-9]/-}.log"
    local attempt=1
    
    start_time=$(date +%s)
    
    while [[ $attempt -le $retry_count ]]; do
        if [[ $retry_count -gt 1 ]]; then
            log_info "Attempt $attempt of $retry_count for: $test_name"
        fi
        
        # Create individual test log
        echo "=== Test: $test_name ===" > "$test_log_file"
        echo "Command: $test_command" >> "$test_log_file"
        echo "Working directory: $working_dir" >> "$test_log_file"
        echo "Timeout: ${timeout}s" >> "$test_log_file"
        echo "Attempt: $attempt" >> "$test_log_file"
        echo "Started: $(date)" >> "$test_log_file"
        echo "===========================================" >> "$test_log_file"
        
        # Run the test with timeout and detailed logging
        local test_result=0
        if cd "$working_dir"; then
            if timeout "$timeout" bash -c "$test_command" >> "$test_log_file" 2>&1; then
                test_result=0
                break  # Success, no need to retry
            else
                test_result=$?
                echo "Exit code: $test_result" >> "$test_log_file"
                
                # Check if it was a timeout
                if [[ $test_result -eq 124 ]]; then
                    log_warning "Test timed out after ${timeout}s: $test_name"
                    echo "TIMEOUT after ${timeout}s" >> "$test_log_file"
                fi
            fi
        else
            test_result=1
            echo "Failed to change to working directory: $working_dir" >> "$test_log_file"
        fi
        
        # If this was the last attempt or test succeeded, break
        if [[ $attempt -eq $retry_count ]] || [[ $test_result -eq 0 ]]; then
            break
        fi
        
        log_warning "Attempt $attempt failed, retrying in 5 seconds..."
        sleep 5
        attempt=$((attempt + 1))
    done
    
    local end_time
    local duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    # Append individual test log to main log
    cat "$test_log_file" >> "$TEST_LOG"
    echo "" >> "$TEST_LOG"
    
    if [[ $test_result -eq 0 ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "PASSED: $test_name (${duration}s)"
        rm -f "$test_log_file"  # Clean up successful test logs
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        
        log_error "FAILED: $test_name (${duration}s)"
        
        # Show relevant error context
        echo -e "${YELLOW}Error context for $test_name:${NC}"
        echo "  Working directory: $working_dir"
        echo "  Command: $test_command"
        echo "  Duration: ${duration}s"
        echo "  Attempts: $attempt"
        
        # Show last meaningful lines from the test log
        echo -e "${YELLOW}Last 15 lines of test output:${NC}"
        tail -n 15 "$test_log_file" | sed 's/^/  /'
        
        # Keep failed test logs for debugging
        log_info "Full test log saved to: $test_log_file"
        
        echo ""
        return 1
    fi
}

# Prerequisites check
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_tools=""
    
    # Check required tools
    for tool in docker kind kubectl ocm flux; do
        if ! command -v "$tool" > /dev/null 2>&1; then
            if [ -z "$missing_tools" ]; then
                missing_tools="$tool"
            else
                missing_tools="$missing_tools $tool"
            fi
        fi
    done
    
    if [ -n "$missing_tools" ]; then
        log_error "Missing required tools: $missing_tools"
        log_info "Run ./scripts/setup-environment.sh to install missing tools"
        return 1
    fi
    
    log_success "All prerequisites available"
    return 0
}

# Test basic examples
test_basic_examples() {
    log_info "Testing basic examples..."
    
    run_test "Basic Examples - Hello World" \
        "./examples/01-basic/hello-world/create-component.sh" \
        "$PROJECT_ROOT" \
        120 \
        2
    
    run_test "Basic Examples - Run All" \
        "./examples/01-basic/run-examples.sh" \
        "$PROJECT_ROOT" \
        180 \
        2
}

# Test transport examples with registry cleanup
test_transport_examples() {
    log_info "Testing transport examples..."
    
    # Clean up any existing registry containers first
    cleanup_registry_containers
    
    # Start main local registry for OCM utils
    run_test "Start Local Registry" \
        "./scripts/ocm-utils.sh registry start" \
        "$PROJECT_ROOT" \
        120 \
        2
    
    # Wait for registry to be ready
    log_info "Waiting for registry to be ready..."
    local wait_count=0
    local max_wait=30
    
    while [[ $wait_count -lt $max_wait ]]; do
        if curl -s "http://localhost:5001/v2/" >/dev/null 2>&1; then
            log_success "Registry is ready"
            break
        fi
        
        wait_count=$((wait_count + 1))
        if [[ $((wait_count % 5)) -eq 0 ]]; then
            log_info "Still waiting for registry... ($wait_count/$max_wait)"
        fi
        sleep 1
    done
    
    if [[ $wait_count -eq $max_wait ]]; then
        log_error "Registry failed to become ready within ${max_wait} seconds"
        return 1
    fi
    
    # Run transport tests with appropriate timeouts
    run_test "Transport - Local to OCI" \
        "./examples/02-transport/local-to-oci/transport-example.sh" \
        "$PROJECT_ROOT" \
        180 \
        2
    
    run_test "Transport - Offline Transport" \
        "./examples/02-transport/offline-transport/offline-example.sh" \
        "$PROJECT_ROOT" \
        180 \
        2
}

# Test K8s deployment examples
test_k8s_examples() {
    log_info "Testing Kubernetes deployment examples..."
    
    # Check if Kind is available
    if ! command -v kind > /dev/null 2>&1; then
        log_warning "Kind not available, skipping Kubernetes tests"
        return 0
    fi
    
    # Clean up registry containers before K8s tests
    cleanup_registry_containers
    
    run_test "K8s - OCM Toolkit Deployment" \
        "./examples/04-k8s-deployment/ocm-k8s-toolkit/deploy-example.sh" \
        "$PROJECT_ROOT" \
        600 \
        2
}

# Print test summary
print_summary() {
    echo
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                              Test Summary                                    ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    echo -e "📊 ${BLUE}Statistics:${NC}"
    echo -e "   Total Tests:  ${BLUE}$TESTS_TOTAL${NC}"
    echo -e "   Passed:       ${GREEN}$TESTS_PASSED${NC}"
    echo -e "   Failed:       ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_TOTAL -gt 0 ]]; then
        local success_rate=$((TESTS_PASSED * 100 / TESTS_TOTAL))
        echo -e "   Success Rate: ${BLUE}${success_rate}%${NC}"
    fi
    
    echo
    echo -e "💾 ${BLUE}Test Environment Info:${NC}"
    echo -e "   Main log: $TEST_LOG"
    echo -e "   Temp logs: /tmp/ocm-test-*.log"
    
    if command -v docker > /dev/null 2>&1; then
        local containers_count
        containers_count=$(docker ps -q | wc -l | tr -d ' ')
        echo -e "   Running containers: $containers_count"
    fi
    
    echo
}

# Main function
main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                        OCM Demo Playground Test Suite                       ║"
    echo "║                                                                              ║"
    echo "║  This script validates all examples and functionality in the playground     ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Initialize test log
    {
        echo "OCM Demo Playground Test Run - $(date)"
        echo "================================="
        echo "Host: $(hostname)"
        echo "User: $(whoami)"
        echo "PWD: $(pwd)"
        echo "Args: $*"
        echo "================================="
        echo
    } > "$TEST_LOG"
    
    # Parse command line arguments
    local skip_k8s=false
    local skip_long=false
    local cleanup_only=false
    local force_cleanup=false
    
    for arg in "$@"; do
        case $arg in
            --skip-k8s)
                skip_k8s=true
                ;;
            --skip-long)
                skip_long=true
                ;;
            --cleanup)
                cleanup_only=true
                ;;
            --force-cleanup)
                force_cleanup=true
                cleanup_only=true
                ;;
            --help|-h)
                echo "Usage: $0 [options]"
                echo ""
                echo "Options:"
                echo "  --skip-k8s       Skip Kubernetes tests"
                echo "  --skip-long      Skip time-consuming tests"
                echo "  --cleanup        Clean up test environment and exit"
                echo "  --force-cleanup  Force cleanup (remove all containers/volumes)"
                echo "  --help, -h       Show this help"
                echo ""
                echo "Examples:"
                echo "  $0                    # Run all tests"
                echo "  $0 --skip-k8s        # Skip Kubernetes tests"
                echo "  $0 --skip-long       # Skip time-consuming tests"
                echo "  $0 --cleanup         # Clean up and exit"
                echo "  $0 --force-cleanup   # Force cleanup and exit"
                exit 0
                ;;
            *)
                log_warning "Unknown option: $arg"
                ;;
        esac
    done
    
    # Handle cleanup-only mode
    if [[ "$cleanup_only" == "true" ]]; then
        cleanup "$force_cleanup"
        log_success "Cleanup completed. Exiting."
        exit 0
    fi
    
    # Show test plan
    echo -e "${BLUE}🚀 Test Plan:${NC}"
    echo "   ✓ Prerequisites check"
    
    if [[ "$skip_long" != "true" ]]; then
        echo "   ✓ Basic examples"
        echo "   ✓ Transport examples"
    else
        echo "   ⏭️  Basic examples (skipped)"
        echo "   ⏭️  Transport examples (skipped)"
    fi
    
    if [[ "$skip_k8s" != "true" ]] && [[ "$skip_long" != "true" ]]; then
        echo "   ✓ Kubernetes deployment"
    else
        echo "   ⏭️  Kubernetes deployment (skipped)"
    fi
    
    echo
    
    # Run test suites
    local overall_success=true
    
    log_info "Starting test execution..."
    
    check_prerequisites || {
        log_error "Prerequisites check failed. Cannot continue."
        overall_success=false
    }
    
    if [[ "$overall_success" == "true" ]]; then
        # Run functional tests if not skipping
        if [[ "$skip_long" != "true" ]]; then
            test_basic_examples
            test_transport_examples
        fi
        
        # Run K8s tests if not skipping
        if [[ "$skip_k8s" != "true" ]] && [[ "$skip_long" != "true" ]]; then
            test_k8s_examples
        fi
    fi
    
    # Print test summary
    print_summary
    
    # Always cleanup registry containers when tests complete
    cleanup_registry_containers
    
    # Final result
    if [[ $TESTS_FAILED -eq 0 ]] && [[ "$overall_success" == "true" ]]; then
        echo -e "${GREEN}🎉 All tests passed! The OCM Demo Playground is working correctly.${NC}"
        echo -e "${GREEN}   Full test log available at: $TEST_LOG${NC}"
        exit 0
    else
        echo -e "${RED}❌ Some tests failed or prerequisites were not met.${NC}"
        echo -e "${RED}   Please review the detailed summary above and check individual logs.${NC}"
        echo -e "${RED}   Full test log available at: $TEST_LOG${NC}"
        echo -e "${YELLOW}   💡 Try running: $0 --cleanup && $0 --skip-long${NC}"
        exit 1
    fi
}

# Run main function with all arguments
main "$@"
