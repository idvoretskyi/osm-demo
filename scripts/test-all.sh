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

# Enhanced test result tracking
declare -A test_results=()
declare -A test_errors=()
declare -A test_durations=()

# Test runner function with enhanced error handling
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
    test_durations["$test_name"]=$duration
    
    # Append individual test log to main log
    cat "$test_log_file" >> "$TEST_LOG"
    echo "" >> "$TEST_LOG"
    
    if [[ $test_result -eq 0 ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        test_results["$test_name"]="PASSED"
        log_success "PASSED: $test_name (${duration}s)"
        rm -f "$test_log_file"  # Clean up successful test logs
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        test_results["$test_name"]="FAILED"
        
        # Capture error details
        local error_summary=""
        if [[ $test_result -eq 124 ]]; then
            error_summary="TIMEOUT after ${timeout}s"
        else
            error_summary="Exit code: $test_result"
            # Try to extract meaningful error from the log
            local last_error
            last_error=$(tail -n 5 "$test_log_file" | grep -i "error\|fail\|exception" | head -n 1 | cut -c1-100)
            if [[ -n "$last_error" ]]; then
                error_summary="$error_summary - $last_error"
            fi
        fi
        
        test_errors["$test_name"]="$error_summary"
        
        log_error "FAILED: $test_name (${duration}s) - $error_summary"
        
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
        
        # Suggest potential fixes based on common error patterns
        suggest_fix "$test_name" "$test_log_file"
        
        echo ""
        return 1
    fi
}

# Function to suggest fixes based on error patterns
suggest_fix() {
    local test_name="$1"
    local log_file="$2"
    
    log_info "Analyzing failure for potential fixes..."
    
    # Check for common error patterns and suggest fixes
    if grep -q "docker.*not found\|docker.*command not found" "$log_file"; then
        echo -e "${YELLOW}💡 Suggestion: Docker is not installed or not in PATH${NC}"
        echo "   Try: curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh"
        
    elif grep -q "kind.*not found\|kind.*command not found" "$log_file"; then
        echo -e "${YELLOW}💡 Suggestion: Kind is not installed${NC}"
        echo "   Try: ./scripts/setup-environment.sh"
        
    elif grep -q "ocm.*not found\|ocm.*command not found" "$log_file"; then
        echo -e "${YELLOW}💡 Suggestion: OCM CLI is not installed${NC}"
        echo "   Try: ./scripts/setup-environment.sh"
        
    elif grep -q "permission denied\|Permission denied" "$log_file"; then
        echo -e "${YELLOW}💡 Suggestion: Permission issues detected${NC}"
        echo "   Try: chmod +x scripts/*.sh examples/*/*.sh"
        
    elif grep -q "connection refused\|Connection refused" "$log_file"; then
        echo -e "${YELLOW}💡 Suggestion: Service connection failed${NC}"
        echo "   Check if required services (Docker, registry) are running"
        echo "   Try: docker ps && ./scripts/ocm-utils.sh status"
        
    elif grep -q "timeout\|Timeout\|timed out" "$log_file"; then
        echo -e "${YELLOW}💡 Suggestion: Operation timed out${NC}"
        echo "   The operation may need more time or there's a networking issue"
        echo "   Try running with --skip-long to skip time-consuming tests"
        
    elif grep -q "No such file or directory" "$log_file"; then
        echo -e "${YELLOW}💡 Suggestion: Missing files detected${NC}"
        echo "   Ensure all required files are present and paths are correct"
        
    elif grep -q "already exists\|already in use" "$log_file"; then
        echo -e "${YELLOW}💡 Suggestion: Resource conflicts detected${NC}"
        echo "   Try cleaning up first: ./scripts/test-all.sh --cleanup"
        
    elif grep -q "registry.*error\|registry.*fail" "$log_file"; then
        echo -e "${YELLOW}💡 Suggestion: Registry issues detected${NC}"
        echo "   Try: ./scripts/ocm-utils.sh registry reset"
        
    else
        echo -e "${YELLOW}💡 Suggestion: Check the full log for more details${NC}"
        echo "   Full log: $log_file"
        echo "   Main log: $TEST_LOG"
    fi
}

# Cleanup function with enhanced options
cleanup() {
    local force_cleanup="${1:-false}"
    
    log_info "Cleaning up test environment..."
    cd "$PROJECT_ROOT"
    
    # Clean up any running containers with enhanced logging
    if command -v docker &> /dev/null; then
        log_info "Stopping and removing Docker containers..."
        local containers=(local-registry demo-registry registry source-registry target-registry source-env-registry target-env-registry)
        
        for container in "${containers[@]}"; do
            if docker ps -q --filter "name=$container" | grep -q .; then
                log_info "Stopping container: $container"
                docker stop "$container" 2>/dev/null || true
            fi
            
            if docker ps -aq --filter "name=$container" | grep -q .; then
                log_info "Removing container: $container"
                docker rm "$container" 2>/dev/null || true
            fi
        done
        
        # Clean up any dangling containers that might have been created during tests
        if [[ "$force_cleanup" == "true" ]]; then
            log_info "Force cleanup: removing all test-related containers and volumes..."
            docker container prune -f 2>/dev/null || true
            docker volume prune -f 2>/dev/null || true
            docker system prune -f 2>/dev/null || true
        fi
    fi
    
    # Clean up kind cluster
    if command -v kind &> /dev/null; then
        log_info "Cleaning up Kind clusters..."
        local clusters=(ocm-demo)
        
        for cluster in "${clusters[@]}"; do
            if kind get clusters 2>/dev/null | grep -q "^$cluster$"; then
                log_info "Deleting Kind cluster: $cluster"
                kind delete cluster --name "$cluster" 2>/dev/null || true
            fi
        done
    fi
    
    # Clean up temporary files and directories
    log_info "Cleaning up temporary files..."
    rm -rf /tmp/ocm-demo/ 2>/dev/null || true
    rm -rf /tmp/ocm-test-*.log 2>/dev/null || true
    rm -rf /tmp/ocm-perf-test 2>/dev/null || true
    
    # Clean up any test artifacts in the project directory
    if [[ "$force_cleanup" == "true" ]]; then
        find "$PROJECT_ROOT" -name "*.ctf" -type f -delete 2>/dev/null || true
        find "$PROJECT_ROOT" -name "component-archive" -type d -exec rm -rf {} + 2>/dev/null || true
    fi
    
    log_success "Cleanup completed"
}

# Prerequisites check
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_tools=()
    
    # Check required tools
    for tool in docker kind kubectl ocm flux; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Run ./scripts/setup-environment.sh to install missing tools"
        return 1
    fi
    
    log_success "All prerequisites available"
    return 0
}

# Test environment setup
test_environment_setup() {
    log_info "Testing environment setup..."
    
    run_test "Environment Setup Script" \
        "./scripts/setup-environment.sh" \
        "$PROJECT_ROOT"
}

# Test basic examples with enhanced error handling
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

# Test transport examples with enhanced error handling
test_transport_examples() {
    log_info "Testing transport examples..."
    
    # Start local registry for transport tests with retry
    run_test "Start Local Registry" \
        "./scripts/ocm-utils.sh registry start" \
        "$PROJECT_ROOT" \
        120 \
        3
    
    # Wait for registry to be ready with verification
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
    
    run_test "Transport Examples - Run All" \
        "./examples/02-transport/run-examples.sh" \
        "$PROJECT_ROOT" \
        300 \
        2
}

# Test signing examples with enhanced error handling
test_signing_examples() {
    log_info "Testing signing examples..."
    
    run_test "Signing - Basic Signing" \
        "./examples/03-signing/basic-signing/sign-component.sh" \
        "$PROJECT_ROOT" \
        120 \
        2
}

# Test Kubernetes deployment examples with enhanced handling
test_k8s_examples() {
    log_info "Testing Kubernetes deployment examples..."
    
    # Check if Kind is available
    if ! command -v kind &> /dev/null; then
        log_warning "Kind not available, skipping Kubernetes tests"
        return 0
    fi
    
    run_test "K8s - Cluster Setup" \
        "./examples/04-k8s-deployment/setup-cluster.sh" \
        "$PROJECT_ROOT" \
        600 \
        2
    
    # Wait for cluster to be ready with verification
    log_info "Waiting for cluster to be ready..."
    local wait_count=0
    local max_wait=60
    
    while [[ $wait_count -lt $max_wait ]]; do
        if kubectl cluster-info >/dev/null 2>&1; then
            log_success "Kubernetes cluster is ready"
            break
        fi
        
        wait_count=$((wait_count + 1))
        if [[ $((wait_count % 10)) -eq 0 ]]; then
            log_info "Still waiting for cluster... ($wait_count/$max_wait)"
        fi
        sleep 1
    done
    
    if [[ $wait_count -eq $max_wait ]]; then
        log_error "Kubernetes cluster failed to become ready within ${max_wait} seconds"
        return 1
    fi
    
    run_test "K8s - OCM Toolkit Deployment" \
        "./examples/04-k8s-deployment/ocm-k8s-toolkit/deploy-example.sh" \
        "$PROJECT_ROOT" \
        600 \
        2
}

# Enhanced test summary with detailed results
print_detailed_summary() {
    echo
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                              Detailed Test Summary                           ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Overall statistics
    echo -e "📊 ${BLUE}Overall Statistics:${NC}"
    echo -e "   Total Tests:  ${BLUE}$TESTS_TOTAL${NC}"
    echo -e "   Passed:       ${GREEN}$TESTS_PASSED${NC}"
    echo -e "   Failed:       ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_TOTAL -gt 0 ]]; then
        local success_rate=$((TESTS_PASSED * 100 / TESTS_TOTAL))
        echo -e "   Success Rate: ${BLUE}${success_rate}%${NC}"
    fi
    
    echo
    
    # Individual test results
    if [[ ${#test_results[@]} -gt 0 ]]; then
        echo -e "📋 ${BLUE}Individual Test Results:${NC}"
        
        # Sort tests by name for consistent output
        local sorted_tests=()
        if [[ ${#test_results[@]} -gt 0 ]]; then
            while IFS= read -r -d '' test_name; do
                sorted_tests+=("$test_name")
            done < <(printf '%s\0' "${!test_results[@]}" | sort -z)
        fi
        
        for test_name in "${sorted_tests[@]:-}"; do
            local result="${test_results[$test_name]}"
            local duration="${test_durations[$test_name]:-N/A}"
            
            if [[ "$result" == "PASSED" ]]; then
                echo -e "   ${GREEN}✅ $test_name${NC} (${duration}s)"
            else
                echo -e "   ${RED}❌ $test_name${NC} (${duration}s)"
                if [[ -n "${test_errors[$test_name]:-}" ]]; then
                    echo -e "      ${RED}└─ ${test_errors[$test_name]}${NC}"
                fi
            fi
        done
        echo
    fi
    
    # Failed tests summary
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "🔍 ${RED}Failed Tests Summary:${NC}"
        local failed_count=0
        
        for test_name in "${!test_results[@]:-}"; do
            if [[ "${test_results[$test_name]}" == "FAILED" ]]; then
                failed_count=$((failed_count + 1))
                echo -e "   ${RED}$failed_count. $test_name${NC}"
                if [[ -n "${test_errors[$test_name]:-}" ]]; then
                    echo -e "      Error: ${test_errors[$test_name]}"
                fi
                
                # Look for corresponding log file
                local test_log_file="/tmp/ocm-test-${test_name//[^a-zA-Z0-9]/-}.log"
                if [[ -f "$test_log_file" ]]; then
                    echo -e "      Log: $test_log_file"
                fi
            fi
        done
        echo
        
        echo -e "🛠️  ${YELLOW}Troubleshooting Tips:${NC}"
        echo -e "   1. Check individual test logs listed above"
        echo -e "   2. Run with --skip-long to skip time-consuming tests"
        echo -e "   3. Try running cleanup first: $0 --cleanup"
        echo -e "   4. Check system requirements: ./scripts/setup-environment.sh"
        echo -e "   5. For Docker issues: docker system info"
        echo -e "   6. For Kind issues: kind get clusters"
        echo
    fi
    
    # Resource usage summary
    echo -e "💾 ${BLUE}Test Environment Info:${NC}"
    echo -e "   Main log: $TEST_LOG"
    echo -e "   Temp logs: /tmp/ocm-test-*.log"
    
    if command -v docker &> /dev/null; then
        local containers_count
        containers_count=$(docker ps -q | wc -l | tr -d ' ')
        echo -e "   Running containers: $containers_count"
    fi
    
    if command -v kind &> /dev/null; then
        local clusters_count
        clusters_count=$(kind get clusters 2>/dev/null | wc -l | tr -d ' ')
        echo -e "   Kind clusters: $clusters_count"
    fi
    
    echo
}

# Test utility scripts with enhanced error handling
test_utility_scripts() {
    log_info "Testing utility scripts..."
    
    run_test "OCM Utils - Help" \
        "./scripts/ocm-utils.sh --help" \
        "$PROJECT_ROOT" \
        30 \
        1
    
    run_test "OCM Utils - Status Check" \
        "./scripts/ocm-utils.sh status" \
        "$PROJECT_ROOT" \
        60 \
        2
    
    run_test "OCM Utils - List Components" \
        "./scripts/ocm-utils.sh list-components" \
        "$PROJECT_ROOT" \
        90 \
        2
}

# Script validation tests
test_script_validation() {
    log_info "Testing script validation..."
    
    # Check that all scripts are executable
    local non_executable=()
    while IFS= read -r -d '' script; do
        if [[ ! -x "$script" ]]; then
            non_executable+=("$script")
        fi
    done < <(find "$PROJECT_ROOT" -name "*.sh" -print0)
    
    if [[ ${#non_executable[@]} -gt 0 ]]; then
        log_error "Non-executable scripts found: ${non_executable[*]}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    else
        log_success "All scripts are executable"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    # Check for shell syntax errors
    local syntax_errors=()
    while IFS= read -r -d '' script; do
        if ! bash -n "$script" 2>/dev/null; then
            syntax_errors+=("$script")
        fi
    done < <(find "$PROJECT_ROOT" -name "*.sh" -print0)
    
    if [[ ${#syntax_errors[@]} -gt 0 ]]; then
        log_error "Scripts with syntax errors: ${syntax_errors[*]}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    else
        log_success "All scripts have valid syntax"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

# Documentation validation
test_documentation() {
    log_info "Testing documentation..."
    
    # Check that all README files exist
    local missing_readmes=()
    for category in examples/*/; do
        if [[ ! -f "${category}README.md" ]]; then
            missing_readmes+=("${category}README.md")
        fi
    done
    
    if [[ ${#missing_readmes[@]} -gt 0 ]]; then
        log_error "Missing README files: ${missing_readmes[*]}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    else
        log_success "All category README files exist"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    # Check main documentation files
    local doc_files=("README.md" "docs/troubleshooting.md" "docs/contributing.md" "LICENSE")
    for doc_file in "${doc_files[@]}"; do
        if [[ -f "$PROJECT_ROOT/$doc_file" ]]; then
            log_success "Documentation file exists: $doc_file"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            log_error "Missing documentation file: $doc_file"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
        TESTS_TOTAL=$((TESTS_TOTAL + 1))
    done
}

# Enhanced performance test
test_performance() {
    log_info "Testing performance..."
    
    local start_time
    start_time=$(date +%s)
    
    # Run a simple component creation to test performance
    run_test "Performance - Component Creation" \
        "cd /tmp && mkdir -p ocm-perf-test && cd ocm-perf-test && ocm create ca --file=test.ctf --provider test.example.com github.com/example/test-component v1.0.0 && rm -rf /tmp/ocm-perf-test" \
        "$PROJECT_ROOT" \
        60 \
        1
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [[ $duration -lt 30 ]]; then
        log_success "Performance test passed (${duration}s)"
    else
        log_warning "Performance test slow (${duration}s) - this may indicate system resource constraints"
    fi
}

# Main test execution with enhanced options
main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                        OCM Demo Playground Test Suite                       ║"
    echo "║                                                                              ║"
    echo "║  This script validates all examples and functionality in the playground     ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Initialize test log with detailed header
    {
        echo "OCM Demo Playground Test Run - $(date)"
        echo "================================="
        echo "Host: $(hostname)"
        echo "User: $(whoami)"
        echo "PWD: $(pwd)"
        echo "Shell: $SHELL"
        echo "Args: $*"
        echo "================================="
        echo
    } > "$TEST_LOG"
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Parse command line arguments
    local skip_k8s=false
    local skip_long=false
    local cleanup_only=false
    local force_cleanup=false
    local verbose=false
    
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
            --verbose|-v)
                verbose=true
                ;;
            --help|-h)
                echo "Usage: $0 [options]"
                echo ""
                echo "Options:"
                echo "  --skip-k8s       Skip Kubernetes tests"
                echo "  --skip-long      Skip time-consuming tests"
                echo "  --cleanup        Clean up test environment and exit"
                echo "  --force-cleanup  Force cleanup (remove all containers/volumes)"
                echo "  --verbose, -v    Enable verbose output"
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
    
    # Enable verbose mode if requested
    if [[ "$verbose" == "true" ]]; then
        set -x
        log_info "Verbose mode enabled"
    fi
    
    # Show test plan
    echo -e "${BLUE}🚀 Test Plan:${NC}"
    echo "   ✓ Prerequisites check"
    echo "   ✓ Script validation"
    echo "   ✓ Documentation validation"
    
    if [[ "$skip_long" != "true" ]]; then
        echo "   ✓ Environment setup"
        echo "   ✓ Basic examples"
        echo "   ✓ Transport examples"
        echo "   ✓ Signing examples"
        echo "   ✓ Utility scripts"
        echo "   ✓ Performance test"
    else
        echo "   ⏭️  Environment setup (skipped)"
        echo "   ⏭️  Basic examples (skipped)"
        echo "   ⏭️  Transport examples (skipped)"
        echo "   ⏭️  Signing examples (skipped)"
        echo "   ⏭️  Utility scripts (skipped)"
        echo "   ⏭️  Performance test (skipped)"
    fi
    
    if [[ "$skip_k8s" != "true" ]] && [[ "$skip_long" != "true" ]]; then
        echo "   ✓ Kubernetes deployment"
    else
        echo "   ⏭️  Kubernetes deployment (skipped)"
    fi
    
    echo
    
    # Run test suites with error handling
    local overall_success=true
    
    log_info "Starting test execution..."
    
    # Always run basic validation
    check_prerequisites || {
        log_error "Prerequisites check failed. Cannot continue."
        overall_success=false
    }
    
    if [[ "$overall_success" == "true" ]]; then
        test_script_validation
        test_documentation
        
        # Run functional tests if not skipping
        if [[ "$skip_long" != "true" ]]; then
            test_environment_setup
            test_basic_examples
            test_transport_examples
            test_signing_examples
            test_utility_scripts
            test_performance
        fi
        
        # Run K8s tests if not skipping
        if [[ "$skip_k8s" != "true" ]] && [[ "$skip_long" != "true" ]]; then
            test_k8s_examples
        fi
    fi
    
    # Print detailed test summary
    print_detailed_summary
    
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
