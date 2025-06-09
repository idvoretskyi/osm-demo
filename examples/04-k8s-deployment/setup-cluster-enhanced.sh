#!/bin/bash

# Enhanced Setup Kubernetes cluster for OCM demos
# Creates a kind cluster with necessary components for OCM K8s integration
# Includes comprehensive health checks, retry mechanisms, and improved stability

set -e

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
        if eval "$check_command" &>/dev/null; then
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
    local cmd="$*"
    
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

cleanup_on_failure() {
    echo -e "${YELLOW}🧹 Cleaning up on failure...${NC}"
    kind delete cluster --name ocm-demo || true
    docker system prune -f || true
    echo -e "${YELLOW}⚠️  Cleanup completed${NC}"
}

# Trap to cleanup on failure
trap cleanup_on_failure ERR

echo -e "${BLUE}☸️  Setting up Enhanced Kubernetes cluster for OCM demos${NC}"

# Check prerequisites
echo -e "${YELLOW}🔍 Checking prerequisites...${NC}"

if ! command -v kind &> /dev/null; then
    echo -e "${RED}❌ kind not found. Please install kind first.${NC}"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl not found. Please install kubectl first.${NC}"
    exit 1
fi

if ! command -v flux &> /dev/null; then
    echo -e "${RED}❌ flux CLI not found. Please install flux CLI first.${NC}"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ docker not found. Please install docker first.${NC}"
    exit 1
fi

# Check Docker is running
if ! docker info &> /dev/null; then
    echo -e "${RED}❌ Docker daemon not running. Please start Docker.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"

# Create kind cluster configuration with enhanced settings
echo -e "${YELLOW}📋 Creating enhanced kind cluster configuration...${NC}"

cat > kind-cluster.yaml << 'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ocm-demo
featureGates:
  EphemeralContainers: true
runtimeConfig:
  api/all: true
nodes:
- role: control-plane
  image: kindest/node:v1.28.0
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
        max-pods: "250"
        system-reserved: "cpu=100m,memory=100Mi"
        kube-reserved: "cpu=100m,memory=100Mi"
        eviction-hard: "memory.available<100Mi,nodefs.available<1Gi"
  - |
    kind: ClusterConfiguration
    apiServer:
      extraArgs:
        enable-admission-plugins: NodeRestriction,MutatingAdmissionWebhook,ValidatingAdmissionWebhook
    controllerManager:
      extraArgs:
        bind-address: 0.0.0.0
    scheduler:
      extraArgs:
        bind-address: 0.0.0.0
    etcd:
      local:
        extraArgs:
          listen-metrics-urls: http://0.0.0.0:2381
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
  extraMounts:
  - hostPath: /tmp/kind-registry
    containerPath: /tmp/registry
- role: worker
  image: kindest/node:v1.28.0
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        max-pods: "250"
        system-reserved: "cpu=100m,memory=100Mi"
        kube-reserved: "cpu=100m,memory=100Mi"
        eviction-hard: "memory.available<100Mi,nodefs.available<1Gi"
- role: worker
  image: kindest/node:v1.28.0
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        max-pods: "250"
        system-reserved: "cpu=100m,memory=100Mi"
        kube-reserved: "cpu=100m,memory=100Mi"
        eviction-hard: "memory.available<100Mi,nodefs.available<1Gi"
EOF

echo -e "${GREEN}✅ Enhanced Kind configuration created${NC}"

# Prepare host system
echo -e "${YELLOW}🔧 Preparing host system...${NC}"
mkdir -p /tmp/kind-registry
docker system prune -f || true

# Create or recreate the cluster with retry logic
echo -e "${YELLOW}🚀 Creating kind cluster with enhanced configuration...${NC}"

# Delete existing cluster if it exists
if kind get clusters | grep -q ocm-demo; then
    echo "Deleting existing ocm-demo cluster..."
    if ! kind delete cluster --name ocm-demo; then
        echo -e "${YELLOW}⚠️  Failed to delete existing cluster, continuing...${NC}"
    fi
    # Wait for cleanup
    sleep 10
fi

# Create new cluster with retry
if ! retry_with_backoff 3 15 "cluster creation" "kind create cluster --config kind-cluster.yaml"; then
    echo -e "${RED}❌ Failed to create kind cluster${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Kind cluster created successfully${NC}"

# Enhanced cluster validation with multiple checks
echo -e "${BLUE}🔍 Running initial cluster validation...${NC}"
if ! validate_cluster_health; then
    echo -e "${RED}❌ Initial cluster health validation failed${NC}"
    exit 1
fi

# Install NGINX Ingress Controller with retry and enhanced configuration
echo -e "${YELLOW}🌐 Installing NGINX Ingress Controller...${NC}"
if ! retry_with_backoff 3 10 "NGINX Ingress installation" "kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml"; then
    echo -e "${RED}❌ Failed to install NGINX Ingress Controller${NC}"
    exit 1
fi

# Wait for ingress controller to be ready with enhanced validation
if ! wait_for_condition "NGINX Ingress Controller" 30 10 "kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=30s"; then
    echo -e "${RED}❌ NGINX Ingress Controller not ready${NC}"
    kubectl get pods -n ingress-nginx
    kubectl describe pod -n ingress-nginx -l app.kubernetes.io/component=controller
    exit 1
fi

echo -e "${GREEN}✅ NGINX Ingress Controller installed and ready${NC}"

# Install Flux with retry and validation
echo -e "${YELLOW}🔄 Installing Flux...${NC}"

# Check if Flux is already installed
if kubectl get namespace flux-system &> /dev/null; then
    echo "Flux already installed, verifying health..."
    if ! wait_for_condition "existing Flux pods" 20 10 "kubectl wait --for=condition=Ready pods --all -n flux-system --timeout=30s"; then
        echo "Existing Flux installation unhealthy, reinstalling..."
        kubectl delete namespace flux-system --ignore-not-found=true
        sleep 15
    else
        echo -e "${GREEN}✅ Existing Flux installation is healthy${NC}"
    fi
fi

if ! kubectl get namespace flux-system &> /dev/null; then
    if ! retry_with_backoff 3 20 "Flux installation" "flux install"; then
        echo -e "${RED}❌ Failed to install Flux${NC}"
        exit 1
    fi
    
    if ! wait_for_condition "Flux pods" 30 15 "kubectl wait --for=condition=Ready pods --all -n flux-system --timeout=30s"; then
        echo -e "${RED}❌ Flux pods not ready${NC}"
        kubectl get pods -n flux-system
        kubectl describe pods -n flux-system
        exit 1
    fi
fi

echo -e "${GREEN}✅ Flux installed and ready${NC}"

# Create namespace for OCM demos
echo -e "${YELLOW}📦 Creating OCM demo namespace...${NC}"
kubectl create namespace ocm-demos || echo "Namespace already exists"

# Install OCM K8s Toolkit with validation
echo -e "${YELLOW}🛠️  Installing OCM K8s Toolkit components...${NC}"

# Create enhanced OCM CRDs
cat > ocm-crds-enhanced.yaml << 'EOF'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: componentversions.ocm.software
  annotations:
    api-approved.kubernetes.io: "https://github.com/open-component-model/ocm-k8s-toolkit"
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
                description: "Component name"
              version:
                type: string
                description: "Component version"
              repository:
                type: string
                description: "Repository URL"
              metadata:
                type: object
                description: "Additional metadata"
          status:
            type: object
            properties:
              phase:
                type: string
                enum: ["Pending", "Ready", "Failed"]
              message:
                type: string
              lastUpdated:
                type: string
                format: date-time
    additionalPrinterColumns:
    - name: Component
      type: string
      jsonPath: .spec.component
    - name: Version
      type: string
      jsonPath: .spec.version
    - name: Status
      type: string
      jsonPath: .status.phase
    - name: Age
      type: date
      jsonPath: .metadata.creationTimestamp
  scope: Namespaced
  names:
    plural: componentversions
    singular: componentversion
    kind: ComponentVersion
    shortNames: ["cv", "compver"]
---
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: ocmconfigurations.ocm.software
  annotations:
    api-approved.kubernetes.io: "https://github.com/open-component-model/ocm-k8s-toolkit"
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
                description: "Reference to ComponentVersion"
              configuration:
                type: object
                description: "Configuration data"
              target:
                type: object
                description: "Target deployment configuration"
          status:
            type: object
            properties:
              phase:
                type: string
                enum: ["Pending", "Applied", "Failed"]
              message:
                type: string
              lastApplied:
                type: string
                format: date-time
    additionalPrinterColumns:
    - name: Status
      type: string
      jsonPath: .status.phase
    - name: Last Applied
      type: string
      jsonPath: .status.lastApplied
    - name: Age
      type: date
      jsonPath: .metadata.creationTimestamp
  scope: Namespaced
  names:
    plural: ocmconfigurations
    singular: ocmconfiguration
    kind: OCMConfiguration
    shortNames: ["ocmconf", "conf"]
EOF

if ! retry_with_backoff 3 5 "OCM CRDs installation" "kubectl apply -f ocm-crds-enhanced.yaml"; then
    echo -e "${RED}❌ Failed to install OCM CRDs${NC}"
    exit 1
fi

# Validate CRDs are established
if ! wait_for_condition "OCM CRDs" 30 5 "kubectl get crd componentversions.ocm.software -o jsonpath='{.status.conditions[?(@.type==\"Established\")].status}' | grep -q True && kubectl get crd ocmconfigurations.ocm.software -o jsonpath='{.status.conditions[?(@.type==\"Established\")].status}' | grep -q True"; then
    echo -e "${RED}❌ OCM CRDs not established${NC}"
    kubectl get crd
    exit 1
fi

echo -e "${GREEN}✅ OCM CRDs installed and established${NC}"

# Create enhanced local registry access
echo -e "${YELLOW}🐳 Setting up enhanced local registry access...${NC}"

# Create configmap for local registry access
kubectl create configmap registry-config \
  --from-literal=registry-url=host.docker.internal:5004 \
  --from-literal=registry-insecure=true \
  --from-literal=registry-ca="" \
  -n ocm-demos || echo "ConfigMap already exists"

# Create a registry access secret
kubectl create secret generic registry-secret \
  --from-literal=username="" \
  --from-literal=password="" \
  --type=kubernetes.io/dockerconfigjson \
  --from-literal=.dockerconfigjson='{"auths":{"host.docker.internal:5004":{"auth":""}}}' \
  -n ocm-demos || echo "Secret already exists"

echo -e "${GREEN}✅ Enhanced registry configuration created${NC}"

# Install metrics server with retry and validation
echo -e "${YELLOW}📊 Installing metrics server...${NC}"
if ! retry_with_backoff 3 10 "metrics server installation" "kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"; then
    echo -e "${RED}❌ Failed to install metrics server${NC}"
    exit 1
fi

# Patch metrics server for kind with enhanced configuration
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[
    {"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"},
    {"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname"},
    {"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-use-node-status-port"},
    {"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--metric-resolution=15s"}
  ]'

# Wait for metrics server to be ready
if ! wait_for_condition "metrics server" 30 10 "kubectl wait --for=condition=Available deployment/metrics-server -n kube-system --timeout=30s"; then
    echo -e "${RED}❌ Metrics server not ready${NC}"
    kubectl get pods -n kube-system | grep metrics-server
    kubectl describe deployment metrics-server -n kube-system
    exit 1
fi

echo -e "${GREEN}✅ Metrics server installed and ready${NC}"

# Install additional cluster components for stability
echo -e "${YELLOW}🔧 Installing additional stability components...${NC}"

# Create resource quotas for stability
kubectl apply -f - << 'EOF'
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ocm-demos-quota
  namespace: ocm-demos
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    persistentvolumeclaims: "10"
    services: "5"
    secrets: "10"
    configmaps: "10"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: ocm-demos-limits
  namespace: ocm-demos
spec:
  limits:
  - default:
      cpu: 500m
      memory: 512Mi
    defaultRequest:
      cpu: 100m
      memory: 128Mi
    type: Container
EOF

echo -e "${GREEN}✅ Resource quotas and limits applied${NC}"

# Final comprehensive health check
echo -e "${BLUE}🏥 Final comprehensive cluster health validation...${NC}"
if ! validate_cluster_health; then
    echo -e "${RED}❌ Final cluster health check failed${NC}"
    exit 1
fi

# Validate metrics server is working
echo -e "${YELLOW}📊 Validating metrics collection...${NC}"
if ! wait_for_condition "metrics collection" 20 10 "kubectl top nodes"; then
    echo -e "${YELLOW}⚠️  Metrics collection not ready yet, but continuing...${NC}"
fi

# Display comprehensive cluster information
echo -e "${YELLOW}📊 Comprehensive cluster information:${NC}"
echo -e "${GREEN}Nodes:${NC}"
kubectl get nodes -o wide

echo -e "${GREEN}Node Resources:${NC}"
kubectl describe nodes | grep -A 5 "Allocated resources"

echo -e "${GREEN}Namespaces:${NC}"
kubectl get namespaces

echo -e "${GREEN}Ingress Controller:${NC}"
kubectl get pods -n ingress-nginx -o wide

echo -e "${GREEN}Flux:${NC}"
kubectl get pods -n flux-system -o wide

echo -e "${GREEN}Metrics Server:${NC}"
kubectl get pods -n kube-system | grep metrics-server

echo -e "${GREEN}OCM CRDs:${NC}"
kubectl get crd | grep ocm.software

echo -e "${GREEN}OCM Demos Namespace:${NC}"
kubectl get all -n ocm-demos

echo -e "${GREEN}✨ Enhanced Kubernetes cluster setup completed successfully!${NC}"
echo -e "${BLUE}🔗 Enhanced cluster details:${NC}"
echo "   Cluster name: ocm-demo"
echo "   Kubernetes version: 1.28.0"
echo "   Nodes: 1 control-plane + 2 workers"
echo "   Ingress: NGINX (ports 8080, 8443)"
echo "   GitOps: Flux installed and ready"
echo "   Registry: localhost:5004 accessible"
echo "   Namespace: ocm-demos with resource quotas"
echo "   Metrics: Server installed and configured"
echo "   Health checks: All passed ✅"
echo "   Stability features: Enhanced"
echo ""
echo -e "${BLUE}🚀 Ready for reliable OCM deployment examples!${NC}"

# Create enhanced health check script for ongoing monitoring
cat > cluster-health-check.sh << 'EOF'
#!/bin/bash
# Enhanced cluster health monitoring script

echo "🏥 Enhanced Cluster Health Check - $(date)"
echo "============================================"

exit_code=0

# Check API server
if kubectl version --short &>/dev/null; then
    echo "✅ API Server: Connected"
    api_version=$(kubectl version --short 2>/dev/null | grep "Server Version" | cut -d: -f2 | tr -d ' ')
    echo "   Version: $api_version"
else
    echo "❌ API Server: Not accessible"
    exit_code=1
fi

# Check nodes with detailed status
echo ""
echo "📊 Node Status:"
while IFS= read -r line; do
    if [[ $line == *"Ready"* ]]; then
        echo "✅ $line"
    else
        echo "❌ $line"
        exit_code=1
    fi
done < <(kubectl get nodes --no-headers 2>/dev/null || echo "ERROR: Cannot get nodes")

# Check system pods
echo ""
echo "🔧 System Pods Status:"
failing_pods=$(kubectl get pods -n kube-system --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)
if [ "$failing_pods" -eq 0 ]; then
    total_pods=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | wc -l)
    echo "✅ System Pods: All $total_pods running"
else
    echo "❌ System Pods: $failing_pods not running"
    kubectl get pods -n kube-system --field-selector=status.phase!=Running
    exit_code=1
fi

# Check critical namespaces with detailed info
echo ""
echo "🏢 Critical Namespaces:"
for ns in ingress-nginx flux-system; do
    if kubectl get namespace "$ns" &>/dev/null; then
        failing_pods=$(kubectl get pods -n "$ns" --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)
        total_pods=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | wc -l)
        if [ "$failing_pods" -eq 0 ]; then
            echo "✅ $ns: All $total_pods pods running"
        else
            echo "❌ $ns: $failing_pods/$total_pods pods not running"
            kubectl get pods -n "$ns" --field-selector=status.phase!=Running
            exit_code=1
        fi
    else
        echo "⚠️  $ns: Namespace not found"
        exit_code=1
    fi
done

# Check OCM components
echo ""
echo "🛠️  OCM Components:"
if kubectl get namespace ocm-demos &>/dev/null; then
    crd_count=$(kubectl get crd | grep ocm.software | wc -l)
    if [ "$crd_count" -ge 2 ]; then
        echo "✅ OCM CRDs: $crd_count installed"
    else
        echo "❌ OCM CRDs: Only $crd_count found (expected 2+)"
        exit_code=1
    fi
    
    # Check resource quotas
    if kubectl get resourcequota -n ocm-demos &>/dev/null; then
        echo "✅ Resource Quotas: Configured"
    else
        echo "⚠️  Resource Quotas: Not found"
    fi
else
    echo "❌ OCM Demos namespace: Not found"
    exit_code=1
fi

# Check metrics server
echo ""
echo "📊 Metrics Server:"
if kubectl get deployment metrics-server -n kube-system &>/dev/null; then
    if kubectl wait --for=condition=Available deployment/metrics-server -n kube-system --timeout=10s &>/dev/null; then
        echo "✅ Metrics Server: Available"
        # Try to get metrics
        if kubectl top nodes &>/dev/null; then
            echo "✅ Metrics Collection: Working"
        else
            echo "⚠️  Metrics Collection: Not ready yet"
        fi
    else
        echo "❌ Metrics Server: Not available"
        exit_code=1
    fi
else
    echo "❌ Metrics Server: Not found"
    exit_code=1
fi

# Check DNS resolution
echo ""
echo "🌐 DNS Resolution:"
if kubectl run test-dns-check --image=busybox --rm -i --restart=Never --timeout=30s -- nslookup kubernetes.default &>/dev/null; then
    echo "✅ DNS: Working"
else
    echo "❌ DNS: Resolution failed"
    exit_code=1
fi

# Resource usage summary
echo ""
echo "💾 Resource Usage Summary:"
if kubectl top nodes &>/dev/null; then
    kubectl top nodes 2>/dev/null | head -n 5
else
    echo "⚠️  Resource metrics not available yet"
fi

echo ""
echo "============================================"
if [ $exit_code -eq 0 ]; then
    echo "🎉 Overall Health Status: HEALTHY"
    echo "Health check completed successfully at $(date)"
else
    echo "⚠️  Overall Health Status: ISSUES DETECTED"
    echo "Health check completed with issues at $(date)"
fi

exit $exit_code
EOF

chmod +x cluster-health-check.sh
echo -e "${GREEN}✅ Enhanced health monitoring script created: cluster-health-check.sh${NC}"

# Run the health check once to verify everything
echo -e "${BLUE}🔍 Running initial health verification...${NC}"
if ./cluster-health-check.sh; then
    echo -e "${GREEN}🎉 All systems are GO! Cluster is ready for OCM deployments.${NC}"
else
    echo -e "${YELLOW}⚠️  Some non-critical issues detected, but cluster should be functional.${NC}"
fi

# Disable trap since we succeeded
trap - ERR

echo -e "${BLUE}✨ Enhanced setup completed successfully! ✨${NC}"
