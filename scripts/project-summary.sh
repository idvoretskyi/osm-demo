#!/bin/bash
set -euo pipefail

# OCM Demo Playground - Project Summary
# This script provides an overview of the playground contents and capabilities

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_section() {
    echo -e "${PURPLE}📂 $1${NC}"
}

log_item() {
    echo -e "${CYAN}  🔹 $1${NC}"
}

print_header() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                           OCM Demo Playground                               ║"
    echo "║                             Project Summary                                  ║"
    echo "║                                                                              ║"
    echo "║  A comprehensive learning environment for the Open Component Model (OCM)    ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

count_files() {
    local pattern="$1"
    find "$PROJECT_ROOT" -name "$pattern" -type f | wc -l | tr -d ' '
}

get_file_size() {
    local path="$1"
    if [[ -f "$path" ]]; then
        du -h "$path" | cut -f1
    else
        echo "N/A"
    fi
}

analyze_project_structure() {
    log_section "Project Structure Analysis"
    
    local total_files
    total_files=$(find "$PROJECT_ROOT" -type f | wc -l | tr -d ' ')
    
    echo -e "  ${YELLOW}Total files:${NC} $total_files"
    echo -e "  ${YELLOW}Shell scripts:${NC} $(count_files "*.sh")"
    echo -e "  ${YELLOW}Documentation files:${NC} $(count_files "*.md")"
    echo -e "  ${YELLOW}Example categories:${NC} $(find "$PROJECT_ROOT/examples" -maxdepth 1 -type d | grep -E '[0-9]{2}-' | wc -l | tr -d ' ')"
    echo
}

analyze_examples() {
    log_section "Examples Overview"
    
    for category_dir in "$PROJECT_ROOT"/examples/*/; do
        if [[ -d "$category_dir" ]]; then
            local category_name
            category_name=$(basename "$category_dir")
            local example_count
            example_count=$(find "$category_dir" -maxdepth 1 -type d | grep -v "^$category_dir$" | wc -l | tr -d ' ')
            
            case $category_name in
                "01-basic")
                    log_item "Basic Examples: $example_count examples - Component creation fundamentals"
                    ;;
                "02-transport")
                    log_item "Transport Examples: $example_count examples - Moving components between repositories"
                    ;;
                "03-signing")
                    log_item "Signing Examples: $example_count examples - Cryptographic security and verification"
                    ;;
                "04-k8s-deployment")
                    log_item "Kubernetes Examples: $example_count examples - Cloud-native deployment patterns"
                    ;;
                *)
                    log_item "$category_name: $example_count examples"
                    ;;
            esac
        fi
    done
    echo
}

analyze_scripts() {
    log_section "Utility Scripts"
    
    for script in "$PROJECT_ROOT"/scripts/*.sh; do
        if [[ -f "$script" ]]; then
            local script_name
            script_name=$(basename "$script")
            local size
            size=$(get_file_size "$script")
            
            case $script_name in
                "setup-environment.sh")
                    log_item "Environment Setup ($size) - Automated tool installation"
                    ;;
                "ocm-utils.sh")
                    log_item "OCM Utilities ($size) - Common operations and management"
                    ;;
                "test-all.sh")
                    log_item "Test Suite ($size) - Comprehensive validation framework"
                    ;;
                "quick-demo.sh")
                    log_item "Quick Demo ($size) - Interactive 5-minute tour"
                    ;;
                "project-summary.sh")
                    log_item "Project Summary ($size) - This overview script"
                    ;;
                *)
                    log_item "$script_name ($size)"
                    ;;
            esac
        fi
    done
    echo
}

check_doc_file() {
    local doc_file="$1"
    local doc_desc="$2"
    if [[ -f "$PROJECT_ROOT/$doc_file" ]]; then
        local size
        size=$(get_file_size "$PROJECT_ROOT/$doc_file")
        log_item "$doc_file ($size) - $doc_desc"
    else
        log_item "$doc_file - Missing"
    fi
}

analyze_documentation() {
    log_section "Documentation"
    
    # Check documentation files one by one
    check_doc_file "README.md" "Main project documentation"
    check_doc_file "docs/troubleshooting.md" "Common issues and solutions"
    check_doc_file "docs/contributing.md" "Contributor guidelines"  
    check_doc_file "docs/ocm-demo-flow.md" "Visual workflow diagrams"
    check_doc_file "LICENSE" "Apache License 2.0"
    echo
}

show_capability() {
    local capability="$1"
    local cap_name=$(echo "$capability" | cut -d':' -f1)
    local cap_desc=$(echo "$capability" | cut -d':' -f2-)
    log_item "$cap_name - $cap_desc"
}

show_capabilities() {
    log_section "OCM Capabilities Demonstrated"
    
    # List capabilities one by one
    show_capability "Component Creation:Package software artifacts with metadata"
    show_capability "Resource Management:Handle different resource types (OCI, files, configs)"
    show_capability "Component Transport:Move components between storage backends"
    show_capability "Digital Signing:Cryptographic integrity and authenticity"
    show_capability "Signature Verification:Trust validation and security policies"
    show_capability "OCI Registry Integration:Standard container registry compatibility"
    show_capability "Offline Transport:Air-gapped deployment scenarios"
    show_capability "Kubernetes Integration:Native K8s deployment patterns"
    show_capability "GitOps Workflows:FluxCD and continuous delivery"
    show_capability "Multi-Environment:Development to production scenarios"
    echo
}

show_learning_path() {
    log_section "Learning Path"
    
    echo -e "  ${YELLOW}🚀 Quickstart (5 min):${NC}"
    echo -e "    ${CYAN}./scripts/quick-demo.sh${NC} - Interactive demo tour"
    echo
    
    echo -e "  ${YELLOW}📚 Beginner (30 min):${NC}"
    echo -e "    ${CYAN}01-basic${NC} - Component creation fundamentals"
    echo -e "    ${CYAN}02-transport${NC} - Basic transport operations"
    echo
    
    echo -e "  ${YELLOW}🔧 Intermediate (1 hour):${NC}"
    echo -e "    ${CYAN}03-signing${NC} - Security and verification"
    echo -e "    ${CYAN}04-k8s-deployment${NC} - Kubernetes integration"
    echo
    
    echo -e "  ${YELLOW}🏗️ Advanced (2+ hours):${NC}"
    echo -e "    ${CYAN}Custom components${NC} - Build your own examples"
    echo -e "    ${CYAN}CI/CD Integration${NC} - Production workflows"
    echo
}

show_command() {
    local cmd_info="$1"
    local cmd=$(echo "$cmd_info" | cut -d':' -f1)
    local cmd_desc=$(echo "$cmd_info" | cut -d':' -f2-)
    echo -e "  ${CYAN}$cmd${NC}"
    echo -e "    $cmd_desc"
    echo
}

show_quick_commands() {
    log_section "Quick Commands"
    
    # List commands one by one
    show_command "./scripts/setup-environment.sh:Set up complete environment"
    show_command "./scripts/quick-demo.sh:Run 5-minute interactive demo"
    show_command "./scripts/ocm-utils.sh status:Check environment status"
    show_command "./scripts/ocm-utils.sh run-all:Execute all examples"
    show_command "./scripts/test-all.sh:Run comprehensive test suite"
    show_command "./scripts/ocm-utils.sh cleanup:Clean up all resources"
}

show_technologies() {
    log_section "Technologies & Tools"
    
    local tools=(
        "OCM CLI:Open Component Model command-line tool"
        "Docker:Container runtime and registry"
        "Kind:Local Kubernetes clusters"
        "Kubectl:Kubernetes command-line tool"
        "Flux:GitOps delivery toolkit"
        "OpenSSL:Cryptographic operations"
        "Bash:Shell scripting environment"
    )
    
    for tool_info in "${tools[@]}"; do
        IFS=':' read -r tool_name tool_desc <<< "$tool_info"
        local tool_cmd
        tool_cmd=$(echo "$tool_name" | tr '[:upper:]' '[:lower:]')
        if command -v "$tool_cmd" > /dev/null 2>&1 || command -v "$tool_name" > /dev/null 2>&1; then
            log_item "$tool_name ✅ - $tool_desc"
        else
            log_item "$tool_name ❌ - $tool_desc"
        fi
    done
    echo
}

main() {
    print_header
    
    analyze_project_structure
    analyze_examples
    analyze_scripts
    analyze_documentation
    show_capabilities
    show_learning_path
    show_quick_commands
    show_technologies
    
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                            Get Started Today!                               ║"
    echo "║                                                                              ║"
    echo "║  1. Run: ./scripts/setup-environment.sh                                     ║"
    echo "║  2. Try: ./scripts/quick-demo.sh                                            ║"
    echo "║  3. Explore: examples/ directory                                            ║"
    echo "║  4. Test: ./scripts/test-all.sh                                             ║"
    echo "║                                                                              ║"
    echo "║  📖 Full documentation: README.md                                           ║"
    echo "║  🔗 OCM Website: https://ocm.software                                       ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Run main function
main "$@"
