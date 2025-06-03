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

analyze_documentation() {
    log_section "Documentation"
    
    local docs=(
        "README.md:Main project documentation"
        "docs/troubleshooting.md:Common issues and solutions"
        "docs/contributing.md:Contributor guidelines"
        "docs/ocm-demo-flow.md:Visual workflow diagrams"
        "LICENSE:Apache License 2.0"
    )
    
    for doc_info in "${docs[@]}"; do
        IFS=':' read -r doc_file doc_desc <<< "$doc_info"
        if [[ -f "$PROJECT_ROOT/$doc_file" ]]; then
            local size
            size=$(get_file_size "$PROJECT_ROOT/$doc_file")
            log_item "$doc_file ($size) - $doc_desc"
        else
            log_item "$doc_file - Missing"
        fi
    done
    echo
}

show_capabilities() {
    log_section "OCM Capabilities Demonstrated"
    
    local capabilities=(
        "Component Creation:Package software artifacts with metadata"
        "Resource Management:Handle different resource types (OCI, files, configs)"
        "Component Transport:Move components between storage backends"
        "Digital Signing:Cryptographic integrity and authenticity"
        "Signature Verification:Trust validation and security policies"
        "OCI Registry Integration:Standard container registry compatibility"
        "Offline Transport:Air-gapped deployment scenarios"
        "Kubernetes Integration:Native K8s deployment patterns"
        "GitOps Workflows:FluxCD and continuous delivery"
        "Multi-Environment:Development to production scenarios"
    )
    
    for capability in "${capabilities[@]}"; do
        IFS=':' read -r cap_name cap_desc <<< "$capability"
        log_item "$cap_name - $cap_desc"
    done
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

show_quick_commands() {
    log_section "Quick Commands"
    
    local commands=(
        "./scripts/setup-environment.sh:Set up complete environment"
        "./scripts/quick-demo.sh:Run 5-minute interactive demo"
        "./scripts/ocm-utils.sh status:Check environment status"
        "./scripts/ocm-utils.sh run-all:Execute all examples"
        "./scripts/test-all.sh:Run comprehensive test suite"
        "./scripts/ocm-utils.sh cleanup:Clean up all resources"
    )
    
    for cmd_info in "${commands[@]}"; do
        IFS=':' read -r cmd cmd_desc <<< "$cmd_info"
        echo -e "  ${CYAN}$cmd${NC}"
        echo -e "    $cmd_desc"
        echo
    done
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
        if command -v "$tool_cmd" &> /dev/null || command -v "$tool_name" &> /dev/null; then
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
