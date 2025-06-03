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
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
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

# Test runner function
run_test() {
    local test_name="$1"
    local test_command="$2"
    local working_dir="${3:-$PROJECT_ROOT}"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "Running test: $test_name"
    
    if cd "$working_dir" && eval "$test_command" >> "$TEST_LOG" 2>&1; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "PASSED: $test_name"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "FAILED: $test_name"
        echo "Last 10 lines of output:"
        tail -n 10 "$TEST_LOG"
        return 1
    fi
}

# Cleanup function
cleanup() {
    log_info "Cleaning up test environment..."
    cd "$PROJECT_ROOT"
    
    # Clean up any running containers
    if command -v docker &> /dev/null; then
        docker stop local-registry demo-registry registry source-registry target-registry source-env-registry target-env-registry 2>/dev/null || true
        docker rm local-registry demo-registry registry source-registry target-registry source-env-registry target-env-registry 2>/dev/null || true
    fi
    
    # Clean up kind cluster
    if command -v kind &> /dev/null; then
        kind delete cluster --name ocm-demo 2>/dev/null || true
    fi
    
    # Clean up temporary files
    rm -rf /tmp/ocm-demo/ 2>/dev/null || true
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

# Test basic examples
test_basic_examples() {
    log_info "Testing basic examples..."
    
    run_test "Basic Examples - Hello World" \
        "./examples/01-basic/hello-world/create-component.sh" \
        "$PROJECT_ROOT"
    
    run_test "Basic Examples - Run All" \
        "./examples/01-basic/run-examples.sh" \
        "$PROJECT_ROOT"
}

# Test transport examples
test_transport_examples() {
    log_info "Testing transport examples..."
    
    # Start local registry for transport tests
    run_test "Start Local Registry" \
        "./scripts/ocm-utils.sh registry start" \
        "$PROJECT_ROOT"
    
    # Wait for registry to be ready
    sleep 5
    
    run_test "Transport - Local to OCI" \
        "./examples/02-transport/local-to-oci/transport-example.sh" \
        "$PROJECT_ROOT"
    
    run_test "Transport - Offline Transport" \
        "./examples/02-transport/offline-transport/offline-example.sh" \
        "$PROJECT_ROOT"
    
    run_test "Transport Examples - Run All" \
        "./examples/02-transport/run-examples.sh" \
        "$PROJECT_ROOT"
}

# Test signing examples
test_signing_examples() {
    log_info "Testing signing examples..."
    
    run_test "Signing - Basic Signing" \
        "./examples/03-signing/basic-signing/sign-component.sh" \
        "$PROJECT_ROOT"
}

# Test Kubernetes deployment examples
test_k8s_examples() {
    log_info "Testing Kubernetes deployment examples..."
    
    run_test "K8s - Cluster Setup" \
        "./examples/04-k8s-deployment/setup-cluster.sh" \
        "$PROJECT_ROOT"
    
    # Wait for cluster to be ready
    log_info "Waiting for cluster to be ready..."
    sleep 30
    
    run_test "K8s - OCM Toolkit Deployment" \
        "./examples/04-k8s-deployment/ocm-k8s-toolkit/deploy-example.sh" \
        "$PROJECT_ROOT"
}

# Test utility scripts
test_utility_scripts() {
    log_info "Testing utility scripts..."
    
    run_test "OCM Utils - Help" \
        "./scripts/ocm-utils.sh --help" \
        "$PROJECT_ROOT"
    
    run_test "OCM Utils - Status Check" \
        "./scripts/ocm-utils.sh status" \
        "$PROJECT_ROOT"
    
    run_test "OCM Utils - List Components" \
        "./scripts/ocm-utils.sh list-components" \
        "$PROJECT_ROOT"
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

# Performance test
test_performance() {
    log_info "Testing performance..."
    
    local start_time=$(date +%s)
    
    # Run a simple component creation to test performance
    run_test "Performance - Component Creation" \
        "cd /tmp && mkdir -p ocm-perf-test && cd ocm-perf-test && ocm create ca --file=test.ctf --provider test.example.com github.com/example/test-component v1.0.0 && rm -rf /tmp/ocm-perf-test" \
        "$PROJECT_ROOT"
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [[ $duration -lt 30 ]]; then
        log_success "Performance test passed (${duration}s)"
    else
        log_warning "Performance test slow (${duration}s)"
    fi
}

# Main test execution
main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                        OCM Demo Playground Test Suite                       ║"
    echo "║                                                                              ║"
    echo "║  This script validates all examples and functionality in the playground     ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Initialize test log
    echo "OCM Demo Playground Test Run - $(date)" > "$TEST_LOG"
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Check if we should skip certain tests
    local skip_k8s=false
    local skip_long=false
    
    for arg in "$@"; do
        case $arg in
            --skip-k8s)
                skip_k8s=true
                ;;
            --skip-long)
                skip_long=true
                ;;
            --help)
                echo "Usage: $0 [options]"
                echo "Options:"
                echo "  --skip-k8s   Skip Kubernetes tests"
                echo "  --skip-long  Skip time-consuming tests"
                echo "  --help       Show this help"
                exit 0
                ;;
        esac
    done
    
    # Run test suites
    check_prerequisites || exit 1
    
    test_script_validation
    test_documentation
    
    if ! $skip_long; then
        test_environment_setup
        test_basic_examples
        test_transport_examples
        test_signing_examples
        test_utility_scripts
        test_performance
    fi
    
    if ! $skip_k8s && ! $skip_long; then
        test_k8s_examples
    fi
    
    # Print test summary
    echo
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                              Test Summary                                    ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "Total Tests:  ${BLUE}$TESTS_TOTAL${NC}"
    echo -e "Passed:       ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed:       ${RED}$TESTS_FAILED${NC}"
    echo
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}🎉 All tests passed! The OCM Demo Playground is working correctly.${NC}"
        echo -e "${GREEN}   Full test log available at: $TEST_LOG${NC}"
        exit 0
    else
        echo -e "${RED}❌ Some tests failed. Please check the issues above.${NC}"
        echo -e "${RED}   Full test log available at: $TEST_LOG${NC}"
        exit 1
    fi
}

# Run main function with all arguments
main "$@"
