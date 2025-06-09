#!/bin/bash
set -euo pipefail

# OCM Demo Playground - Basic Validation
# This script validates the playground structure and scripts without requiring all tools

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

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_test() {
    echo -e "${PURPLE}🧪 $1${NC}"
}

run_test() {
    local test_name="$1"
    local test_result="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "Testing: $test_name"
    
    if [[ "$test_result" == "0" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "PASSED: $test_name"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "FAILED: $test_name"
        return 1
    fi
}

print_header() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    OCM Demo Playground - Basic Validation                   ║"
    echo "║                                                                              ║"
    echo "║  Validates project structure and scripts without requiring tool installation ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Test project structure
test_project_structure() {
    log_info "Testing project structure..."
    
    # Test main directories exist
    local required_dirs=("examples" "scripts" "docs")
    local missing_dirs=()
    
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$PROJECT_ROOT/$dir" ]]; then
            missing_dirs+=("$dir")
        fi
    done
    
    if [[ ${#missing_dirs[@]} -eq 0 ]]; then
        run_test "Required directories exist" "0"
    else
        log_error "Missing directories: ${missing_dirs[*]}"
        run_test "Required directories exist" "1"
    fi
    
    # Test example categories exist
    local example_categories=("01-basic" "02-transport" "03-signing" "04-k8s-deployment")
    local missing_categories=()
    
    for category in "${example_categories[@]}"; do
        if [[ ! -d "$PROJECT_ROOT/examples/$category" ]]; then
            missing_categories+=("$category")
        fi
    done
    
    if [[ ${#missing_categories[@]} -eq 0 ]]; then
        run_test "Example categories exist" "0"
    else
        log_error "Missing example categories: ${missing_categories[*]}"
        run_test "Example categories exist" "1"
    fi
}

# Test script permissions
test_script_permissions() {
    log_info "Testing script permissions..."
    
    local non_executable=()
    while IFS= read -r -d '' script; do
        if [[ ! -x "$script" ]]; then
            non_executable+=("$script")
        fi
    done < <(find "$PROJECT_ROOT" -name "*.sh" -print0)
    
    if [[ ${#non_executable[@]} -eq 0 ]]; then
        run_test "All scripts are executable" "0"
    else
        log_error "Non-executable scripts: ${non_executable[*]}"
        run_test "All scripts are executable" "1"
    fi
}

# Test script syntax
test_script_syntax() {
    log_info "Testing script syntax..."
    
    local syntax_errors=()
    while IFS= read -r -d '' script; do
        if ! bash -n "$script" 2>/dev/null; then
            syntax_errors+=("$script")
        fi
    done < <(find "$PROJECT_ROOT" -name "*.sh" -print0)
    
    if [[ ${#syntax_errors[@]} -eq 0 ]]; then
        run_test "All scripts have valid syntax" "0"
    else
        log_error "Scripts with syntax errors: ${syntax_errors[*]}"
        run_test "All scripts have valid syntax" "1"
    fi
}

# Test documentation
test_documentation() {
    log_info "Testing documentation..."
    
    # Test main documentation files
    local doc_files=("README.md" "LICENSE" "docs/troubleshooting.md" "docs/contributing.md")
    local missing_docs=()
    
    for doc_file in "${doc_files[@]}"; do
        if [[ ! -f "$PROJECT_ROOT/$doc_file" ]]; then
            missing_docs+=("$doc_file")
        fi
    done
    
    if [[ ${#missing_docs[@]} -eq 0 ]]; then
        run_test "Documentation files exist" "0"
    else
        log_error "Missing documentation: ${missing_docs[*]}"
        run_test "Documentation files exist" "1"
    fi
    
    # Test that each example category has a README
    local missing_readmes=()
    for category in "$PROJECT_ROOT"/examples/*/; do
        if [[ ! -f "${category}README.md" ]]; then
            missing_readmes+=("${category}README.md")
        fi
    done
    
    if [[ ${#missing_readmes[@]} -eq 0 ]]; then
        run_test "Example READMEs exist" "0"
    else
        log_error "Missing example READMEs: ${missing_readmes[*]}"
        run_test "Example READMEs exist" "1"
    fi
}

# Test utility scripts
test_utility_scripts() {
    log_info "Testing utility scripts..."
    
    # Test that utility scripts exist and are executable
    local util_scripts=("setup-environment.sh" "ocm-utils.sh" "test-all.sh" "quick-demo.sh" "project-summary.sh")
    local missing_utils=()
    
    for script in "${util_scripts[@]}"; do
        if [[ ! -x "$PROJECT_ROOT/scripts/$script" ]]; then
            missing_utils+=("$script")
        fi
    done
    
    if [[ ${#missing_utils[@]} -eq 0 ]]; then
        run_test "Utility scripts exist and are executable" "0"
    else
        log_error "Missing or non-executable utilities: ${missing_utils[*]}"
        run_test "Utility scripts exist and are executable" "1"
    fi
    
    # Test that ocm-utils.sh help works
    if "$PROJECT_ROOT/scripts/ocm-utils.sh" --help > /dev/null 2>&1; then
        run_test "OCM utils help command works" "0"
    else
        run_test "OCM utils help command works" "1"
    fi
}

# Test example structure
test_example_structure() {
    log_info "Testing example structure..."
    
    # Test that each category has a run-examples.sh script
    local missing_runners=()
    for category in "$PROJECT_ROOT"/examples/*/; do
        if [[ -d "$category" && ! -x "${category}run-examples.sh" ]]; then
            missing_runners+=("${category}run-examples.sh")
        fi
    done
    
    if [[ ${#missing_runners[@]} -eq 0 ]]; then
        run_test "Example runner scripts exist" "0"
    else
        log_error "Missing example runners: ${missing_runners[*]}"
        run_test "Example runner scripts exist" "1"
    fi
    
    # Count total examples
    local total_examples=0
    for category in "$PROJECT_ROOT"/examples/*/; do
        if [[ -d "$category" ]]; then
            local examples_in_category
            examples_in_category=$(find "$category" -maxdepth 1 -type d | grep -v "^$category$" | wc -l | tr -d ' ')
            total_examples=$((total_examples + examples_in_category))
        fi
    done
    
    if [[ $total_examples -ge 6 ]]; then
        run_test "Sufficient examples available ($total_examples)" "0"
    else
        run_test "Sufficient examples available ($total_examples)" "1"
    fi
}

# Test workflow integration
test_workflow_integration() {
    log_info "Testing workflow integration..."
    
    # Test GitHub Actions workflow exists
    if [[ -f "$PROJECT_ROOT/.github/workflows/ci.yml" ]]; then
        run_test "CI/CD workflow file exists" "0"
    else
        run_test "CI/CD workflow file exists" "1"
    fi
    
    # Test that mermaid flow diagrams exist
    if [[ -f "$PROJECT_ROOT/docs/ocm-demo-flow.md" ]]; then
        run_test "Flow diagrams documentation exists" "0"
    else
        run_test "Flow diagrams documentation exists" "1"
    fi
}

# Main execution
main() {
    print_header
    
    test_project_structure
    echo
    
    test_script_permissions
    echo
    
    test_script_syntax
    echo
    
    test_documentation
    echo
    
    test_utility_scripts
    echo
    
    test_example_structure
    echo
    
    test_workflow_integration
    echo
    
    # Print summary
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                              Validation Summary                              ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "Total Tests:  ${BLUE}$TESTS_TOTAL${NC}"
    echo -e "Passed:       ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed:       ${RED}$TESTS_FAILED${NC}"
    echo
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}🎉 All validation tests passed!${NC}"
        echo -e "${GREEN}   The OCM Demo Playground structure is complete and ready to use.${NC}"
        echo
        echo -e "${BLUE}Next steps:${NC}"
        echo -e "  1. Install tools: ${CYAN}./scripts/setup-environment.sh${NC}"
        echo -e "  2. Try quick demo: ${CYAN}./scripts/quick-demo.sh${NC}"
        echo -e "  3. Run full tests: ${CYAN}./scripts/test-all.sh${NC}"
        exit 0
    else
        echo -e "${RED}❌ Some validation tests failed.${NC}"
        echo -e "${RED}   Please fix the issues above before proceeding.${NC}"
        exit 1
    fi
}

# Run main function
main "$@"
