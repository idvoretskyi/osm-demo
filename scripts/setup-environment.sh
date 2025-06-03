#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check and install OCM CLI
install_ocm_cli() {
    if command_exists ocm; then
        print_success "OCM CLI is already installed ($(ocm version))"
        return 0
    fi

    print_status "Installing OCM CLI..."
    
    # Detect OS and architecture
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        arm64|aarch64) ARCH="arm64" ;;
        *) print_error "Unsupported architecture: $ARCH"; exit 1 ;;
    esac
    
    # Get latest release
    LATEST_RELEASE=$(curl -s https://api.github.com/repos/open-component-model/ocm/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
    
    if [ -z "$LATEST_RELEASE" ]; then
        print_error "Failed to get latest OCM CLI release"
        exit 1
    fi
    
    print_status "Downloading OCM CLI ${LATEST_RELEASE} for ${OS}-${ARCH}..."
    
    # Download and install
    # Fix version format for download URL
    VERSION_NO_V=${LATEST_RELEASE#v}
    DOWNLOAD_URL="https://github.com/open-component-model/ocm/releases/download/${LATEST_RELEASE}/ocm-${VERSION_NO_V}-${OS}-${ARCH}.tar.gz"
    TEMP_DIR=$(mktemp -d)
    
    curl -sL "$DOWNLOAD_URL" | tar -xz -C "$TEMP_DIR"
    
    # Install to /usr/local/bin if possible, otherwise to ~/bin
    if [ -w "/usr/local/bin" ]; then
        sudo mv "$TEMP_DIR/ocm" /usr/local/bin/
        print_success "OCM CLI installed to /usr/local/bin/ocm"
    else
        mkdir -p "$HOME/bin"
        mv "$TEMP_DIR/ocm" "$HOME/bin/"
        print_success "OCM CLI installed to $HOME/bin/ocm"
        print_warning "Make sure $HOME/bin is in your PATH"
    fi
    
    rm -rf "$TEMP_DIR"
}

# Function to check Docker
check_docker() {
    if command_exists docker; then
        if docker info >/dev/null 2>&1; then
            print_success "Docker is running"
        else
            print_error "Docker is installed but not running. Please start Docker."
            exit 1
        fi
    else
        print_error "Docker is not installed. Please install Docker first."
        print_status "Visit: https://docs.docker.com/get-docker/"
        exit 1
    fi
}

# Function to check and install kind
install_kind() {
    if command_exists kind; then
        print_success "kind is already installed ($(kind version))"
        return 0
    fi

    print_status "Installing kind..."
    
    # Detect OS and architecture
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        arm64|aarch64) ARCH="arm64" ;;
        *) print_error "Unsupported architecture: $ARCH"; exit 1 ;;
    esac
    
    # Download and install kind
    DOWNLOAD_URL="https://kind.sigs.k8s.io/dl/v0.20.0/kind-${OS}-${ARCH}"
    
    if [ -w "/usr/local/bin" ]; then
        curl -sLo /usr/local/bin/kind "$DOWNLOAD_URL"
        chmod +x /usr/local/bin/kind
        print_success "kind installed to /usr/local/bin/kind"
    else
        mkdir -p "$HOME/bin"
        curl -sLo "$HOME/bin/kind" "$DOWNLOAD_URL"
        chmod +x "$HOME/bin/kind"
        print_success "kind installed to $HOME/bin/kind"
        print_warning "Make sure $HOME/bin is in your PATH"
    fi
}

# Function to check and install kubectl
install_kubectl() {
    if command_exists kubectl; then
        print_success "kubectl is already installed ($(kubectl version --client --short 2>/dev/null || kubectl version --client))"
        return 0
    fi

    print_status "Installing kubectl..."
    
    # Detect OS and architecture
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        arm64|aarch64) ARCH="arm64" ;;
        *) print_error "Unsupported architecture: $ARCH"; exit 1 ;;
    esac
    
    # Get stable version
    KUBECTL_VERSION=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
    DOWNLOAD_URL="https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/${OS}/${ARCH}/kubectl"
    
    if [ -w "/usr/local/bin" ]; then
        curl -sLo /usr/local/bin/kubectl "$DOWNLOAD_URL"
        chmod +x /usr/local/bin/kubectl
        print_success "kubectl installed to /usr/local/bin/kubectl"
    else
        mkdir -p "$HOME/bin"
        curl -sLo "$HOME/bin/kubectl" "$DOWNLOAD_URL"
        chmod +x "$HOME/bin/kubectl"
        print_success "kubectl installed to $HOME/bin/kubectl"
        print_warning "Make sure $HOME/bin is in your PATH"
    fi
}

# Function to check and install Flux CLI
install_flux_cli() {
    if command_exists flux; then
        print_success "Flux CLI is already installed ($(flux version --client --short 2>/dev/null || echo 'installed'))"
        return 0
    fi

    print_status "Installing Flux CLI..."
    
    curl -s https://fluxcd.io/install.sh | bash
    
    if [ -f "$HOME/.flux/bin/flux" ]; then
        if [ -w "/usr/local/bin" ]; then
            sudo mv "$HOME/.flux/bin/flux" /usr/local/bin/
            print_success "Flux CLI installed to /usr/local/bin/flux"
        else
            mkdir -p "$HOME/bin"
            mv "$HOME/.flux/bin/flux" "$HOME/bin/"
            print_success "Flux CLI installed to $HOME/bin/flux"
            print_warning "Make sure $HOME/bin is in your PATH"
        fi
    fi
}

# Function to create directories
create_directories() {
    print_status "Creating project directories..."
    
    local dirs=(
        "examples/01-basic/hello-world"
        "examples/01-basic/multi-resource"
        "examples/02-transport/local-to-oci"
        "examples/02-transport/cross-registry"
        "examples/03-signing/basic-signing"
        "examples/03-signing/verification"
        "examples/04-k8s-deployment/simple-helm"
        "examples/04-k8s-deployment/bootstrap"
        "examples/05-advanced/component-references"
        "examples/05-advanced/localization"
        "infrastructure/registry"
        "infrastructure/kind"
        "docs"
        "scripts/utils"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
    done
    
    print_success "Created project directory structure"
}

# Function to set up local registry
setup_local_registry() {
    print_status "Setting up local OCI registry..."
    
    # Check if registry container is already running
    if docker ps --format '{{.Names}}' | grep -q "^local-registry$"; then
        print_success "Local registry is already running"
        return 0
    fi
    
    # Stop and remove existing registry if it exists but isn't running
    if docker ps -a --format '{{.Names}}' | grep -q "^local-registry$"; then
        docker rm -f local-registry >/dev/null 2>&1
    fi
    
    # Start new registry
    docker run -d \
        --name local-registry \
        --restart=always \
        -p 5001:5000 \
        registry:2 >/dev/null
    
    # Wait for registry to be ready
    for i in {1..30}; do
        if curl -f http://localhost:5001/v2/ >/dev/null 2>&1; then
            print_success "Local registry is running on http://localhost:5001"
            return 0
        fi
        sleep 1
    done
    
    print_error "Failed to start local registry"
    exit 1
}

# Main function
main() {
    print_status "Setting up OCM Demo Playground environment..."
    echo
    
    # Check prerequisites
    check_docker
    
    # Install tools
    install_kind
    install_kubectl
    install_ocm_cli
    install_flux_cli
    
    # Set up project structure
    create_directories
    
    # Set up local infrastructure
    setup_local_registry
    
    echo
    print_success "Environment setup complete!"
    echo
    print_status "Next steps:"
    echo "  1. cd examples/01-basic/hello-world"
    echo "  2. ./run-example.sh"
    echo
    print_status "For Kubernetes examples:"
    echo "  1. cd examples/04-k8s-deployment"
    echo "  2. ./setup-cluster.sh"
    echo "  3. ./deploy-example.sh"
}

# Run main function
main "$@"
