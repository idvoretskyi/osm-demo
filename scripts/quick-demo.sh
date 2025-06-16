#!/usr/bin/env bash
set -euo pipefail

# OCM Demo Playground - Quick Demo
# This script runs a curated selection of examples to showcase OCM capabilities

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly DEMO_DURATION=300  # 5 minutes for quick demo

# Source common functions
source "$SCRIPT_DIR/common.sh"

# Legacy function wrapper for compatibility
log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_demo() {
    echo -e "${PURPLE}🎬 $1${NC}"
}

log_step() {
    echo -e "${CYAN}🔹 $1${NC}"
}

print_header() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                           OCM Demo Playground                               ║"
    echo "║                             Quick Demo Tour                                 ║"
    echo "║                                                                              ║"
    echo "║  This 5-minute demo showcases the key features of the Open Component Model  ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_footer() {
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                               Demo Complete!                                ║"
    echo "║                                                                              ║"
    echo "║  🎉 You've seen the key OCM capabilities in action!                        ║"
    echo "║                                                                              ║"
    echo "║  Next steps:                                                                 ║"
    echo "║  • Explore individual examples in examples/                                  ║"
    echo "║  • Run the full test suite: ./scripts/test-all.sh                          ║"
    echo "║  • Read the docs: README.md and docs/                                       ║"
    echo "║  • Join the OCM community: https://github.com/open-component-model/        ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

wait_for_user() {
    echo -e "${YELLOW}⏳ Press Enter to continue to the next step...${NC}"
    read -r
}

cleanup() {
    log_info "Cleaning up demo artifacts..."
    rm -rf /tmp/ocm-demo-quick/ 2>/dev/null || true
}

check_prerequisites() {
    log_demo "Checking prerequisites..."
    
    local missing_tools=()
    
    for tool in ocm docker; do
        if ! command -v "$tool" > /dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Run './scripts/setup-environment.sh' to install missing tools"
        exit 1
    fi
    
    log_success "All prerequisites available"
}

demo_component_creation() {
    log_demo "Step 1: Creating your first OCM component"
    log_step "OCM components package software artifacts with metadata and signatures"
    
    # Create demo workspace
    mkdir -p /tmp/ocm-demo-quick/components
    cd /tmp/ocm-demo-quick/components
    
    # Create a simple component
    log_step "Creating component with a text resource..."
    
    cat > hello.txt << 'EOF'
Hello from OCM! 
This is a simple text resource packaged in an OCM component.
EOF
    
    # Create component archive
    ocm create componentarchive demo.ocm/hello-world v1.0.0 \
        --provider ocm-demo \
        --file hello-component.ctf
    
    # Add resource
    ocm add resources hello-component.ctf \
        --name hello-text \
        --type plainText \
        --version v1.0.0 \
        --inputType file \
        --inputPath hello.txt
    
    # Show component contents
    log_step "Component created! Here's what's inside:"
    ocm get components -o yaml hello-component.ctf
    
    log_success "✨ Component creation complete!"
    wait_for_user
}

demo_component_transport() {
    log_demo "Step 2: Transporting components between repositories"
    log_step "OCM components can be moved between different storage backends"
    
    # Start local registry if not running
    if ! curl -s http://localhost:5001/v2/ > /dev/null; then
        log_step "Starting local OCI registry..."
        docker run -d -p 5001:5000 --name demo-registry registry:2 || true
        sleep 3
    fi
    
    # Transport to OCI registry
    log_step "Moving component from local archive to OCI registry..."
    ocm transfer component hello-component.ctf http://localhost:5001/demo
    
    # Verify in registry
    log_step "Verifying component in registry:"
    ocm get components http://localhost:5001/demo//demo.ocm/hello-world:v1.0.0
    
    log_success "✨ Component transport complete!"
    wait_for_user
}

demo_component_signing() {
    log_demo "Step 3: Signing components for security"
    log_step "OCM supports cryptographic signatures for integrity and authenticity"
    
    # Generate RSA key pair
    log_step "Generating RSA key pair..."
    mkdir -p /tmp/ocm-demo-quick/keys
    openssl genrsa -out /tmp/ocm-demo-quick/keys/private.pem 2048 2>/dev/null
    openssl rsa -in /tmp/ocm-demo-quick/keys/private.pem -pubout -out /tmp/ocm-demo-quick/keys/public.pem 2>/dev/null
    
    # Sign the component
    log_step "Signing component with private key..."
    ocm sign componentversion \
        --signature=demo-signature \
        --private-key=/tmp/ocm-demo-quick/keys/private.pem \
        http://localhost:5001/demo//demo.ocm/hello-world:v1.0.0
    
    # Verify signature
    log_step "Verifying signature with public key..."
    ocm verify componentversion \
        --signature=demo-signature \
        --public-key=/tmp/ocm-demo-quick/keys/public.pem \
        http://localhost:5001/demo//demo.ocm/hello-world:v1.0.0
    
    log_success "✨ Component signing and verification complete!"
    wait_for_user
}

demo_component_extraction() {
    log_demo "Step 4: Extracting resources from components"
    log_step "OCM components can be consumed by extracting their resources"
    
    mkdir -p /tmp/ocm-demo-quick/extracted
    cd /tmp/ocm-demo-quick/extracted
    
    # Download component resource
    log_step "Downloading the hello-text resource..."
    ocm download resource http://localhost:5001/demo//demo.ocm/hello-world:v1.0.0 hello-text
    
    # Show downloaded content
    log_step "Content of downloaded resource:"
    cat hello-text
    
    log_success "✨ Resource extraction complete!"
    wait_for_user
}

demo_summary() {
    log_demo "Demo Summary"
    log_step "In this 5-minute demo, you experienced:"
    echo
    echo -e "  ${GREEN}📦 Component Creation${NC} - Packaged a text file into an OCM component"
    echo -e "  ${GREEN}🚀 Component Transport${NC} - Moved component from local archive to OCI registry"
    echo -e "  ${GREEN}🔐 Digital Signing${NC} - Secured component with cryptographic signatures"
    echo -e "  ${GREEN}📤 Resource Extraction${NC} - Retrieved and used component resources"
    echo
    log_step "These building blocks enable:"
    echo -e "  • ${CYAN}Software Supply Chain Security${NC}"
    echo -e "  • ${CYAN}Universal Software Delivery${NC}"
    echo -e "  • ${CYAN}GitOps and Kubernetes Integration${NC}"
    echo -e "  • ${CYAN}Air-gapped Deployments${NC}"
    echo
}

main() {
    # Set up cleanup trap
    trap cleanup EXIT
    
    print_header
    
    # Check if user wants interactive mode
    local interactive=true
    for arg in "$@"; do
        case $arg in
            --non-interactive|--ci)
                interactive=false
                ;;
            --help)
                echo "Usage: $0 [options]"
                echo "Options:"
                echo "  --non-interactive  Run without user prompts"
                echo "  --ci               Same as --non-interactive"
                echo "  --help             Show this help"
                exit 0
                ;;
        esac
    done
    
    # Override wait function for non-interactive mode
    if ! $interactive; then
        wait_for_user() {
            sleep 2
        }
    fi
    
    log_info "Starting OCM Demo Playground Quick Tour..."
    echo
    
    # Run demo steps
    check_prerequisites
    echo
    
    demo_component_creation
    echo
    
    demo_component_transport
    echo
    
    demo_component_signing
    echo
    
    demo_component_extraction
    echo
    
    demo_summary
    
    # Clean up demo registry
    docker stop demo-registry 2>/dev/null || true
    docker rm demo-registry 2>/dev/null || true
    
    print_footer
}

# Run main function with all arguments
main "$@"
