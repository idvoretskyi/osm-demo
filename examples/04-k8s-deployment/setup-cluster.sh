#!/bin/bash

# Setup Kubernetes cluster for OCM demos
# Creates a kind cluster with necessary components for OCM K8s integration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Enhanced health check and retry functions
wait_for_condition() {
    local description="$1"
    local max_attempts="${2:-30}"
    local wait_time="${3:-10}"
    local check_command="$4"
    
    echo -e "${YELLOW}⏳ Waiting for $description (max ${max_attempts} attempts, ${wait_time}s intervals)...${NC}"
    
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        echo "  Attempt $attempt/$max_attempts..."
        if eval "$check_command" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ $description ready${NC}"
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            echo "  Not ready yet, waiting ${wait_time}s..."
            sleep $wait_time
        fi
        ((attempt++))
    done
    
    echo -e "${RED}❌ Timeout waiting for $description${NC}"
    return 1
}

validate_cluster_health() {
    echo -e "${BLUE}🏥 Performing comprehensive cluster health check...${NC}"
    
    # Check API server connectivity
    if ! wait_for_condition "API server" 20 5 "kubectl version --short"; then
        echo -e "${RED}❌ API server not accessible${NC}"
        return 1
    fi
    
    # Check all nodes are ready
    if ! wait_for_condition "all nodes to be Ready" 30 10 "kubectl wait --for=condition=Ready nodes --all --timeout=30s"; then
        echo -e "${RED}❌ Not all nodes are ready${NC}"
        kubectl get nodes -o wide
        return 1
    fi
    
    # Check system pods are running
    if ! wait_for_condition "system pods" 30 10 "kubectl get pods -n kube-system --field-selector=status.phase!=Running --no-headers | wc -l | grep -q '^0$'"; then
        echo -e "${RED}❌ Some system pods are not running${NC}"
        kubectl get pods -n kube-system --field-selector=status.phase!=Running
        return 1
    fi
    
    # Check DNS is working
    if ! wait_for_condition "DNS resolution" 15 5 "kubectl run test-dns --image=busybox --rm -i --restart=Never -- nslookup kubernetes.default"; then
        echo -e "${RED}❌ DNS resolution not working${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Cluster health validation passed${NC}"
    return 0
}

retry_with_backoff() {
    local max_attempts="$1"
    local delay="$2"
    local description="$3"
    shift 3
    local cmd="$@"
    
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        echo "Attempting $description (attempt $attempt/$max_attempts)..."
        if eval "$cmd"; then
            echo -e "${GREEN}✅ $description succeeded${NC}"
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            local wait_time=$((delay * attempt))
            echo "  Failed, waiting ${wait_time}s before retry..."
            sleep $wait_time
        fi
        ((attempt++))
    done
    
    echo -e "${RED}❌ $description failed after $max_attempts attempts${NC}"
    return 1
}

echo -e "${BLUE}☸️  Setting up Kubernetes cluster for OCM demos${NC}"

# Check prerequisites
echo -e "${YELLOW}🔍 Checking prerequisites...${NC}"

if ! command -v kind > /dev/null 2>&1; then
    echo -e "${RED}❌ kind not found. Please install kind first.${NC}"
    exit 1
fi

if ! command -v kubectl > /dev/null 2>&1; then
    echo -e "${RED}❌ kubectl not found. Please install kubectl first.${NC}"
    exit 1
fi

if ! command -v flux > /dev/null 2>&1; then
    echo -e "${RED}❌ flux CLI not found. Please install flux CLI first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"

# Create kind cluster configuration
echo -e "${YELLOW}📋 Creating kind cluster configuration...${NC}"

cat > kind-config.yaml << 'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ocm-demo
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 8080
    protocol: TCP
  - containerPort: 443
    hostPort: 8443
    protocol: TCP
  - containerPort: 5000
    hostPort: 5004
    protocol: TCP
- role: worker
- role: worker
EOF

echo -e "${GREEN}✅ Kind configuration created${NC}"

# Create or recreate the cluster with retry logic
echo -e "${YELLOW}🚀 Creating kind cluster...${NC}"

# Delete existing cluster if it exists
if kind get clusters | grep -q ocm-demo; then
    echo "Deleting existing ocm-demo cluster..."
    if ! kind delete cluster --name ocm-demo; then
        echo -e "${YELLOW}⚠️  Failed to delete existing cluster, continuing...${NC}"
    fi
    # Wait a bit for cleanup
    sleep 5
fi

# Create new cluster with retry
if ! retry_with_backoff 3 10 "cluster creation" "kind create cluster --config kind-config.yaml"; then
    echo -e "${RED}❌ Failed to create kind cluster${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Kind cluster created${NC}"

# Enhanced cluster validation
if ! validate_cluster_health; then
    echo -e "${RED}❌ Cluster health validation failed${NC}"
    exit 1
fi

# Install NGINX Ingress Controller with retry
echo -e "${YELLOW}🌐 Installing NGINX Ingress Controller...${NC}"
if ! retry_with_backoff 3 10 "NGINX Ingress installation" "kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml"; then
    echo -e "${RED}❌ Failed to install NGINX Ingress Controller${NC}"
    exit 1
fi

# Wait for ingress controller to be ready with enhanced validation
if ! wait_for_condition "NGINX Ingress Controller" 30 10 "kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=30s"; then
    echo -e "${RED}❌ NGINX Ingress Controller not ready${NC}"
    kubectl get pods -n ingress-nginx
    exit 1
fi

echo -e "${GREEN}✅ NGINX Ingress Controller installed and ready${NC}"

# Install Flux with retry and validation
echo -e "${YELLOW}🔄 Installing Flux...${NC}"

# Check if Flux is already installed
if kubectl get namespace flux-system > /dev/null 2>&1; then
    echo "Flux already installed, verifying health..."
    if ! wait_for_condition "existing Flux pods" 20 10 "kubectl wait --for=condition=Ready pods --all -n flux-system --timeout=30s"; then
        echo "Existing Flux installation unhealthy, reinstalling..."
        kubectl delete namespace flux-system --ignore-not-found=true
        sleep 10
    else
        echo -e "${GREEN}✅ Existing Flux installation is healthy${NC}"
    fi
fi

if ! kubectl get namespace flux-system > /dev/null 2>&1; then
    if ! retry_with_backoff 3 15 "Flux installation" "flux install"; then
        echo -e "${RED}❌ Failed to install Flux${NC}"
        exit 1
    fi
    
    if ! wait_for_condition "Flux pods" 30 10 "kubectl wait --for=condition=Ready pods --all -n flux-system --timeout=30s"; then
        echo -e "${RED}❌ Flux pods not ready${NC}"
        kubectl get pods -n flux-system
        exit 1
    fi
fi

echo -e "${GREEN}✅ Flux installed and ready${NC}"

# Create namespace for OCM demos
echo -e "${YELLOW}📦 Creating OCM demo namespace...${NC}"
kubectl create namespace ocm-demos || echo "Namespace already exists"

# Install OCM K8s Toolkit with validation
echo -e "${YELLOW}🛠️  Installing OCM K8s Toolkit components...${NC}"

# Create OCM CRDs (simplified for demo)
cat > ocm-crds.yaml << 'EOF'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: componentversions.ocm.software
spec:
  group: ocm.software
  versions:
  - name: v1alpha1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              component:
                type: string
              version:
                type: string
              repository:
                type: string
          status:
            type: object
  scope: Namespaced
  names:
    plural: componentversions
    singular: componentversion
    kind: ComponentVersion
---
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: ocmconfigurations.ocm.software
spec:
  group: ocm.software
  versions:
  - name: v1alpha1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              componentVersion:
                type: object
              configuration:
                type: object
          status:
            type: object
  scope: Namespaced
  names:
    plural: ocmconfigurations
    singular: ocmconfiguration
    kind: OCMConfiguration
EOF

if ! retry_with_backoff 3 5 "OCM CRDs installation" "kubectl apply -f ocm-crds.yaml"; then
    echo -e "${RED}❌ Failed to install OCM CRDs${NC}"
    exit 1
fi

# Validate CRDs are established
if ! wait_for_condition "OCM CRDs" 20 5 "kubectl get crd componentversions.ocm.software -o jsonpath='{.status.conditions[?(@.type==\"Established\")].status}' | grep -q True && kubectl get crd ocmconfigurations.ocm.software -o jsonpath='{.status.conditions[?(@.type==\"Established\")].status}' | grep -q True"; then
    echo -e "${RED}❌ OCM CRDs not established${NC}"
    kubectl get crd
    exit 1
fi

echo -e "${GREEN}✅ OCM CRDs installed and established${NC}"

# Create local registry access
echo -e "${YELLOW}🐳 Setting up local registry access...${NC}"

# Create configmap for local registry access
kubectl create configmap registry-config \
  --from-literal=registry-url=host.docker.internal:5004 \
  -n ocm-demos || echo "ConfigMap already exists"

echo -e "${GREEN}✅ Registry configuration created${NC}"

# Install metrics server with retry and validation
echo -e "${YELLOW}📊 Installing metrics server...${NC}"
if ! retry_with_backoff 3 10 "metrics server installation" "kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"; then
    echo -e "${RED}❌ Failed to install metrics server${NC}"
    exit 1
fi

# Patch metrics server for kind
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

# Wait for metrics server to be ready
if ! wait_for_condition "metrics server" 30 10 "kubectl wait --for=condition=Available deployment/metrics-server -n kube-system --timeout=30s"; then
    echo -e "${RED}❌ Metrics server not ready${NC}"
    kubectl get pods -n kube-system | grep metrics-server
    exit 1
fi

echo -e "${GREEN}✅ Metrics server installed and ready${NC}"

# Final comprehensive health check
echo -e "${BLUE}🏥 Final cluster health validation...${NC}"
if ! validate_cluster_health; then
    echo -e "${RED}❌ Final cluster health check failed${NC}"
    exit 1
fi

# Display cluster information
echo -e "${YELLOW}📊 Cluster information:${NC}"
echo -e "${GREEN}Nodes:${NC}"
kubectl get nodes -o wide

echo -e "${GREEN}Namespaces:${NC}"
kubectl get namespaces

echo -e "${GREEN}Ingress Controller:${NC}"
kubectl get pods -n ingress-nginx

echo -e "${GREEN}Flux:${NC}"
kubectl get pods -n flux-system

echo -e "${GREEN}Metrics Server:${NC}"
kubectl get pods -n kube-system | grep metrics-server

echo -e "${GREEN}✨ Kubernetes cluster setup completed successfully!${NC}"
echo -e "${BLUE}🔗 Cluster details:${NC}"
echo "   Cluster name: ocm-demo"
echo "   Nodes: 1 control-plane + 2 workers"
echo "   Ingress: NGINX (ports 8080, 8443)"
echo "   GitOps: Flux installed"
echo "   Registry: localhost:5004 accessible"
echo "   Namespace: ocm-demos"
echo "   Health checks: All passed"
echo ""
echo -e "${BLUE}🚀 Ready for OCM deployment examples!${NC}"

# Create a health check script for ongoing monitoring
cat > cluster-health-check.sh << 'EOF'
#!/bin/bash
# Cluster health monitoring script

echo "🏥 Cluster Health Check - $(date)"
echo "=============================="

# Check API server
if kubectl version --short > /dev/null 2>&1; then
    echo "✅ API Server: Connected"
else
    echo "❌ API Server: Not accessible"
    exit 1
fi

# Check nodes
not_ready_nodes=$(kubectl get nodes --no-headers | grep -v Ready | wc -l)
if [ "$not_ready_nodes" -eq 0 ]; then
    echo "✅ Nodes: All ready ($(kubectl get nodes --no-headers | wc -l) total)"
else
    echo "❌ Nodes: $not_ready_nodes not ready"
    kubectl get nodes
fi

# Check system pods
failing_pods=$(kubectl get pods -n kube-system --field-selector=status.phase!=Running --no-headers | wc -l)
if [ "$failing_pods" -eq 0 ]; then
    echo "✅ System Pods: All running"
else
    echo "❌ System Pods: $failing_pods not running"
    kubectl get pods -n kube-system --field-selector=status.phase!=Running
fi

# Check critical namespaces
for ns in ingress-nginx flux-system; do
    if kubectl get namespace "$ns" > /dev/null 2>&1; then
        failing_pods=$(kubectl get pods -n "$ns" --field-selector=status.phase!=Running --no-headers | wc -l)
        if [ "$failing_pods" -eq 0 ]; then
            echo "✅ $ns: All pods running"
        else
            echo "❌ $ns: $failing_pods pods not running"
        fi
    else
        echo "⚠️  $ns: Namespace not found"
    fi
done

echo "=============================="
echo "Health check completed at $(date)"
EOF

chmod +x cluster-health-check.sh
echo -e "${GREEN}✅ Health monitoring script created: cluster-health-check.sh${NC}"
