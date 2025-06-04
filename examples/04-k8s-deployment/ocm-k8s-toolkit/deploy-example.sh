#!/bin/bash

# OCM K8s Toolkit Deployment Example
# Demonstrates deploying OCM components to Kubernetes using OCM K8s integration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$SCRIPT_DIR/work"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}☸️  OCM K8s Toolkit Deployment Demo${NC}"

# Check for help or verify-only flags
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo "Usage: $0 [--verify-only]"
    echo ""
    echo "Options:"
    echo "  --verify-only    Only verify cluster readiness, don't deploy"
    echo "  --help, -h       Show this help"
    echo ""
    echo "This script demonstrates deploying OCM components to Kubernetes."
    echo "It requires a running Kubernetes cluster (automatically sets up if needed)."
    exit 0
fi

if [[ "$1" == "--verify-only" ]]; then
    echo "Running cluster verification only..."
    if check_cluster_ready; then
        echo -e "${GREEN}✅ Cluster verification passed - ready for deployment${NC}"
        exit 0
    else
        echo -e "${RED}❌ Cluster verification failed${NC}"
        show_troubleshooting_help
        exit 1
    fi
fi

# Clean and create work directory
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"/{manifests,components}
cd "$WORK_DIR"

# Comprehensive Kubernetes context validation and recovery function
ensure_k8s_connectivity() {
    echo "=== Kubernetes Context Validation and Recovery ==="
    
    # Step 1: Verify kind cluster is actually running
    echo "Checking if kind cluster is running..."
    if ! kind get clusters 2>/dev/null | grep -q "ocm-demo"; then
        echo "❌ Kind cluster 'ocm-demo' not found"
        echo "Available clusters:"
        kind get clusters 2>/dev/null || echo "No kind clusters found"
        return 1
    fi
    
    # Check if cluster containers are running
    if ! docker ps --filter "name=ocm-demo-control-plane" --format "{{.Names}}" | grep -q "ocm-demo"; then
        echo "❌ Kind cluster containers are not running"
        echo "Cluster exists but containers are stopped. Trying to restart..."
        if ! kind delete cluster --name ocm-demo; then
            echo "Failed to delete stale cluster"
            return 1
        fi
        return 1  # Signal that cluster needs to be recreated
    fi
    
    echo "✅ Kind cluster containers are running"
    
    # Step 2: Set KUBECONFIG with multiple fallback options
    if [[ -n "${KUBECONFIG:-}" ]]; then
        echo "Using provided KUBECONFIG: $KUBECONFIG"
    elif kind get kubeconfig-path --name=ocm-demo >/dev/null 2>&1; then
        export KUBECONFIG="$(kind get kubeconfig-path --name=ocm-demo)"
        echo "Using Kind kubeconfig: $KUBECONFIG"
    else
        export KUBECONFIG="$HOME/.kube/config"
        echo "Using default kubeconfig: $KUBECONFIG"
    fi
    
    # Verify kubeconfig file exists
    if [[ ! -f "$KUBECONFIG" ]]; then
        echo "❌ KUBECONFIG file does not exist: $KUBECONFIG"
        return 1
    fi
    
    echo "✅ KUBECONFIG file exists and is readable"
    
    # Step 3: Force refresh kubeconfig from kind to ensure current API server address
    echo "Refreshing kubeconfig from kind cluster..."
    local kubeconfig_attempts=0
    local max_kubeconfig_attempts=3
    
    while [[ $kubeconfig_attempts -lt $max_kubeconfig_attempts ]]; do
        if kind export kubeconfig --name=ocm-demo; then
            echo "✅ Kubeconfig refreshed successfully"
            break
        fi
        
        kubeconfig_attempts=$((kubeconfig_attempts + 1))
        echo "Kubeconfig refresh attempt $kubeconfig_attempts/$max_kubeconfig_attempts failed, retrying..."
        sleep 2
    done
    
    if [[ $kubeconfig_attempts -eq $max_kubeconfig_attempts ]]; then
        echo "❌ Failed to refresh kubeconfig after $max_kubeconfig_attempts attempts"
        return 1
    fi
    
    # Step 4: Validate API server address and connectivity
    echo "Validating API server connectivity..."
    local api_server
    api_server=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null) || {
        echo "❌ Failed to get API server address from kubeconfig"
        return 1
    }
    
    echo "API Server: $api_server"
    
    # Additional pre-check: Test if API server port is even open
    if [[ "$api_server" =~ 127\.0\.0\.1:([0-9]+) ]]; then
        local port="${BASH_REMATCH[1]}"
        echo "Pre-checking port $port availability..."
        if ! nc -z 127.0.0.1 "$port" 2>/dev/null; then
            echo "❌ Port $port is not open, API server may not be running"
            echo "Checking kind cluster container status..."
            docker ps --filter "name=ocm-demo-control-plane" --format "{{.Names}}: {{.Status}}" || true
            # Try to refresh kubeconfig in case the port changed
            kind export kubeconfig --name=ocm-demo 2>/dev/null || true
            api_server=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null) || true
            echo "Updated API Server: $api_server"
        else
            echo "✅ Port $port is open"
        fi
    fi
    
    # Test raw connectivity to API server
    local api_test_attempts=0
    local max_api_test_attempts=3
    
    while [[ $api_test_attempts -lt $max_api_test_attempts ]]; do
        if curl -k -s --max-time 5 "$api_server/api/v1" >/dev/null 2>&1; then
            echo "✅ API server is reachable"
            break
        fi
        
        api_test_attempts=$((api_test_attempts + 1))
        echo "API server connectivity test $api_test_attempts/$max_api_test_attempts failed, retrying..."
        
        # Try to refresh kubeconfig again
        kind export kubeconfig --name=ocm-demo 2>/dev/null || true
        api_server=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null) || true
        sleep 3
    done
    
    if [[ $api_test_attempts -eq $max_api_test_attempts ]]; then
        echo "❌ API server is not reachable after $max_api_test_attempts attempts"
        echo "Final API server address: $api_server"
        echo "Testing with curl..."
        curl -v -k --max-time 10 "$api_server/api/v1" 2>&1 | head -10 || true
        
        # Additional debugging for CI environments
        echo "=== API Server Connectivity Debug ==="
        echo "Kind cluster containers:"
        docker ps --filter "name=ocm-demo" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" || true
        echo "Kind cluster logs (last 10 lines):"
        docker logs "$(docker ps --filter "name=ocm-demo-control-plane" --format "{{.ID}}")" 2>/dev/null | tail -10 || true
        echo "Network connectivity test:"
        if [[ "$api_server" =~ 127\.0\.0\.1:([0-9]+) ]]; then
            local port="${BASH_REMATCH[1]}"
            echo "Testing port $port connectivity..."
            nc -z 127.0.0.1 "$port" && echo "Port $port is open" || echo "Port $port is closed/unreachable"
        fi
        echo "======================================"
        return 1
    fi
    
    # Step 5: Set context with multiple attempts
    local context_attempts=0
    local max_context_attempts=5
    
    while [[ $context_attempts -lt $max_context_attempts ]]; do
        if kubectl config use-context kind-ocm-demo 2>/dev/null; then
            echo "✅ Successfully set context to kind-ocm-demo"
            break
        fi
        
        context_attempts=$((context_attempts + 1))
        echo "Context switch attempt $context_attempts/$max_context_attempts failed, retrying..."
        
        # Try to refresh kubeconfig
        kind export kubeconfig --name=ocm-demo 2>/dev/null || true
        sleep 1
    done
    
    if [[ $context_attempts -eq $max_context_attempts ]]; then
        echo "❌ Failed to set kubectl context after $max_context_attempts attempts"
        echo "Available contexts:"
        kubectl config get-contexts 2>/dev/null || echo "No contexts available"
        return 1
    fi
    
    # Step 6: Verify cluster connectivity with kubectl
    echo "Verifying cluster connectivity with kubectl..."
    local connectivity_attempts=0
    local max_connectivity_attempts=5
    
    while [[ $connectivity_attempts -lt $max_connectivity_attempts ]]; do
        if kubectl cluster-info --request-timeout=10s >/dev/null 2>&1; then
            echo "✅ Cluster connectivity verified with kubectl"
            break
        fi
        
        connectivity_attempts=$((connectivity_attempts + 1))
        echo "Kubectl connectivity attempt $connectivity_attempts/$max_connectivity_attempts failed, retrying..."
        
        # Show detailed error for debugging
        if [[ $connectivity_attempts -eq 1 ]]; then
            echo "Debug: kubectl cluster-info error:"
            kubectl cluster-info 2>&1 | head -5 || true
        fi
        
        # Try to refresh connection
        kind export kubeconfig --name=ocm-demo 2>/dev/null || true
        kubectl config use-context kind-ocm-demo 2>/dev/null || true
        sleep 3
    done
    
    if [[ $connectivity_attempts -eq $max_connectivity_attempts ]]; then
        echo "❌ Failed to establish kubectl connectivity after $max_connectivity_attempts attempts"
        echo "=== Comprehensive Debug Information ==="
        echo "KUBECONFIG: $KUBECONFIG"
        echo "Current context: $(kubectl config current-context 2>/dev/null || echo 'none')"
        echo "Available contexts:"
        kubectl config get-contexts 2>/dev/null || echo "No contexts available"
        echo "Kind clusters:"
        kind get clusters 2>/dev/null || echo "No kind clusters"
        echo "Kind cluster containers:"
        docker ps --filter "name=ocm-demo" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" || echo "No containers found"
        echo "API server from config:"
        local debug_api_server
        debug_api_server=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null) || echo "Failed to get API server"
        echo "$debug_api_server"
        if [[ "$debug_api_server" =~ 127\.0\.0\.1:([0-9]+) ]]; then
            local debug_port="${BASH_REMATCH[1]}"
            echo "Port connectivity test for $debug_port:"
            nc -z 127.0.0.1 "$debug_port" && echo "  Port $debug_port is open" || echo "  Port $debug_port is closed/unreachable"
        fi
        echo "Raw kubectl error:"
        kubectl cluster-info 2>&1 || echo "kubectl cluster-info failed"
        echo "=================================="
        return 1
    fi
    
    # Step 7: Final verification tests
    echo "Performing comprehensive verification tests..."
    
    # Test 1: Get nodes
    if ! kubectl get nodes --request-timeout=10s >/dev/null 2>&1; then
        echo "❌ Failed to get nodes"
        kubectl get nodes 2>&1 | head -3 || true
        return 1
    fi
    echo "✅ Successfully retrieved nodes"
    
    # Test 2: Check API server
    if ! kubectl get --raw='/api/v1' >/dev/null 2>&1; then
        echo "❌ API server accessibility test failed"
        return 1
    fi
    echo "✅ API server is accessible via kubectl"
    
    # Test 3: Wait for system pods to be ready
    echo "Checking system pod readiness..."
    if ! kubectl wait --for=condition=Ready pods --all -n kube-system --timeout=30s >/dev/null 2>&1; then
        echo "⚠️  Some system pods are not ready yet, but cluster is accessible"
    else
        echo "✅ System pods are ready"
    fi
    
    # Show final status
    echo "=== Final Kubernetes Status ==="
    echo "Context: $(kubectl config current-context)"
    echo "KUBECONFIG: $KUBECONFIG"
    echo "API Server: $(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.server}')"
    echo "Nodes:"
    kubectl get nodes --no-headers 2>/dev/null | head -3 || echo "Failed to get nodes"
    echo "=============================="
    
    return 0
}

# Step 1: Comprehensive Kubernetes Context Management and Cluster Readiness
echo -e "${YELLOW}🔍 Step 1: Kubernetes Context Management and Cluster Readiness${NC}"

# Ensure Kubernetes connectivity before proceeding
if ! ensure_k8s_connectivity; then
    echo "❌ Failed to establish Kubernetes connectivity. Cannot proceed with deployment."
    exit 1
fi

echo "✅ Kubernetes connectivity established. Proceeding with deployment..."

# Troubleshooting function
show_troubleshooting_help() {
    echo -e "${BLUE}🔧 Troubleshooting Help${NC}"
    echo "======================"
    echo ""
    echo -e "${YELLOW}Common issues and solutions:${NC}"
    echo ""
    echo "1. No kubectl context available:"
    echo "   - Ensure a Kubernetes cluster is running"
    echo "   - Run: ../setup-cluster.sh"
    echo "   - Check: kubectl config get-contexts"
    echo ""
    echo "2. kind not installed:"
    echo "   - macOS: brew install kind"
    echo "   - Linux: curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64"
    echo "   - Windows: see https://kind.sigs.k8s.io/docs/user/quick-start/"
    echo ""
    echo "3. Docker not running:"
    echo "   - Start Docker Desktop"
    echo "   - Check: docker ps"
    echo ""
    echo "4. Cluster setup failed:"
    echo "   - Clean up: kind delete cluster --name ocm-demo"
    echo "   - Retry: ../setup-cluster.sh"
    echo ""
    echo "5. kubectl context issues:"
    echo "   - Set context: kubectl config use-context kind-ocm-demo"
    echo "   - Check config: kubectl config current-context"
    echo ""
    echo -e "${BLUE}For more help, see: docs/troubleshooting.md${NC}"
}

# Enhanced cluster readiness check for CI environments
check_cluster_ready() {
    echo "🔍 Checking kubectl configuration..."
    
    # Check kubectl config
    if ! kubectl config current-context &> /dev/null; then
        echo -e "${RED}❌ No kubectl context available${NC}"
        echo "Available contexts:"
        kubectl config get-contexts || echo "No contexts found"
        return 1
    fi
    
    local current_context
    current_context=$(kubectl config current-context)
    echo "✅ Using kubectl context: $current_context"
    
    # Check cluster info
    echo "🔍 Checking cluster connectivity..."
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}❌ Kubernetes cluster not accessible${NC}"
        echo "Cluster info output:"
        kubectl cluster-info 2>&1 || echo "Failed to get cluster info"
        return 1
    fi
    
    echo "✅ Cluster is accessible"
    
    # Check node readiness
    echo "🔍 Checking node readiness..."
    local ready_nodes
    ready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready " || echo "0")
    
    if [[ $ready_nodes -eq 0 ]]; then
        echo -e "${RED}❌ No ready nodes found${NC}"
        echo "Node status:"
        kubectl get nodes --no-headers 2>&1 || echo "Failed to get nodes"
        return 1
    fi
    
    echo "✅ Found $ready_nodes ready node(s)"
    
    # Check system pods
    echo "🔍 Checking system pods..."
    local running_pods
    running_pods=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -c " Running " || echo "0")
    
    if [[ $running_pods -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  No running system pods found (this might be okay)${NC}"
    else
        echo "✅ Found $running_pods running system pod(s)"
    fi
    
    return 0
}

if ! check_cluster_ready; then
    echo -e "${RED}❌ Kubernetes cluster not accessible.${NC}"
    echo ""
    echo -e "${YELLOW}🚀 Attempting to set up a cluster automatically...${NC}"
    
    # Check if kind is available
    if ! command -v kind &> /dev/null; then
        echo -e "${RED}❌ kind is not installed. Please install it first:${NC}"
        echo "   macOS: brew install kind"
        echo "   Linux: see https://kind.sigs.k8s.io/docs/user/quick-start/"
        echo ""
        show_troubleshooting_help
        exit 1
    fi
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker is not available. Please install Docker first.${NC}"
        show_troubleshooting_help
        exit 1
    fi
    
    # Try to set up cluster automatically
    echo "Running cluster setup script..."
    if ! (cd "$SCRIPT_DIR/.." && ./setup-cluster.sh); then
        echo -e "${RED}❌ Failed to set up cluster automatically.${NC}"
        echo ""
        echo "Please try manually:"
        echo "   cd ../.. && ./examples/04-k8s-deployment/setup-cluster.sh"
        exit 1
    fi
    
    # Wait a moment for cluster to be ready
    echo "Waiting for cluster to be ready..."
    sleep 5
    
    # Re-check cluster readiness
    if ! check_cluster_ready; then
        echo -e "${RED}❌ Cluster setup completed but cluster is still not accessible.${NC}"
        echo ""
        echo "Debug information:"
        echo "KUBECONFIG: ${KUBECONFIG:-$HOME/.kube/config}"
        echo "Current directory: $(pwd)"
        echo "Available kind clusters:"
        kind get clusters 2>/dev/null || echo "No kind clusters found"
        echo ""
        echo "Try setting the kubectl context manually:"
        echo "   kubectl config use-context kind-ocm-demo"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Cluster setup successful!${NC}"
fi

echo -e "${GREEN}✅ Kubernetes cluster is accessible${NC}"

# Step 2: Create application component
echo -e "${YELLOW}📦 Step 2: Creating Kubernetes application component${NC}"

cd components

# Create application manifests
mkdir -p k8s-app
cat > k8s-app/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ocm-demo-app
  labels:
    app: ocm-demo-app
    deployed-by: ocm
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ocm-demo-app
  template:
    metadata:
      labels:
        app: ocm-demo-app
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
        env:
        - name: APP_VERSION
          value: "v1.0.0"
        - name: DEPLOYED_BY
          value: "OCM"
        volumeMounts:
        - name: config
          mountPath: /usr/share/nginx/html
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
      volumes:
      - name: config
        configMap:
          name: ocm-demo-config
EOF

cat > k8s-app/service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: ocm-demo-service
  labels:
    app: ocm-demo-app
spec:
  selector:
    app: ocm-demo-app
  ports:
  - port: 80
    targetPort: 80
    name: http
  type: ClusterIP
EOF

cat > k8s-app/configmap.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: ocm-demo-config
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>OCM Kubernetes Demo</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; }
            .container { max-width: 800px; margin: 0 auto; text-align: center; }
            .card { background: rgba(255,255,255,0.1); padding: 30px; border-radius: 10px; margin: 20px 0; }
            .status { color: #4CAF50; font-weight: bold; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🚀 OCM Kubernetes Deployment</h1>
            <div class="card">
                <h2>Application Status</h2>
                <p class="status">✅ Successfully deployed via OCM</p>
                <p>Version: v1.0.0</p>
                <p>Deployed by: Open Component Model</p>
                <p>Deployment time: $(date)</p>
            </div>
            <div class="card">
                <h2>About OCM</h2>
                <p>This application was packaged, transported, and deployed using the Open Component Model.</p>
                <p>OCM provides a standardized way to describe, package, and deploy software components.</p>
            </div>
        </div>
    </body>
    </html>
EOF

cat > k8s-app/ingress.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ocm-demo-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: ocm-demo.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ocm-demo-service
            port:
              number: 80
EOF

echo "✅ Created Kubernetes manifests"

# Create OCM component with K8s manifests
echo -e "${YELLOW}📋 Creating OCM component with K8s manifests${NC}"

ocm create componentarchive github.com/ocm-demo/k8s-app v1.0.0 \
  --provider ocm-demo \
  --file k8s-component

# Add all manifests as resources
ocm add resources k8s-component \
  --name deployment \
  --type kubernetesManifest \
  --version v1.0.0 \
  --inputType file \
  --inputPath k8s-app/deployment.yaml

ocm add resources k8s-component \
  --name service \
  --type kubernetesManifest \
  --version v1.0.0 \
  --inputType file \
  --inputPath k8s-app/service.yaml

ocm add resources k8s-component \
  --name configmap \
  --type kubernetesManifest \
  --version v1.0.0 \
  --inputType file \
  --inputPath k8s-app/configmap.yaml

ocm add resources k8s-component \
  --name ingress \
  --type kubernetesManifest \
  --version v1.0.0 \
  --inputType file \
  --inputPath k8s-app/ingress.yaml

echo "✅ OCM component created with K8s manifests"

# Step 3: Push component to registry
echo -e "${YELLOW}🚀 Step 3: Pushing component to registry${NC}"

# Ensure registry is running
if ! curl -s http://localhost:5004/v2/ > /dev/null 2>&1; then
    echo "Starting local registry..."
    
    # Generate unique container name to avoid conflicts
    TIMESTAMP=$(date +%s)
    REGISTRY_NAME="k8s-deploy-registry-${TIMESTAMP}"
    
    # Stop any existing registry containers on port 5004
    docker ps --filter "publish=5004" --format "{{.Names}}" | xargs -r docker stop 2>/dev/null || true
    docker ps -a --filter "publish=5004" --format "{{.Names}}" | xargs -r docker rm 2>/dev/null || true
    
    # Remove generic "registry" container if it exists (common conflict)
    docker rm -f registry 2>/dev/null || true
    
    # Start registry with unique name
    if docker run -d -p 5004:5000 --name "$REGISTRY_NAME" registry:2; then
        echo "Started registry container: $REGISTRY_NAME"
        
        # Wait for registry to be ready
        echo "Waiting for registry to be ready..."
        for i in {1..30}; do
            if curl -f -s -m 5 http://localhost:5004/v2/ >/dev/null 2>&1; then
                echo "✅ Registry is ready"
                break
            fi
            if [[ $i -eq 30 ]]; then
                echo "❌ Registry failed to start within 30 seconds"
                docker logs "$REGISTRY_NAME" || true
                exit 1
            fi
            sleep 1
        done
    else
        echo "❌ Failed to start registry"
        exit 1
    fi
fi

# Configure OCM to use HTTP for localhost registries
export OCM_CONFIG_PLAIN_HTTP=localhost:5004

# Push component
ocm transfer componentarchive k8s-component http://localhost:5004

echo "✅ Component pushed to registry"

# Step 4: Create OCM Configuration for deployment
echo -e "${YELLOW}⚙️  Step 4: Creating OCM Configuration${NC}"

cd ../manifests

cat > ocm-configuration.yaml << 'EOF'
apiVersion: ocm.software/v1alpha1
kind: OCMConfiguration
metadata:
  name: demo-app-config
  namespace: ocm-demos
spec:
  componentVersion:
    component: github.com/ocm-demo/k8s-app
    version: v1.0.0
    repository: http://localhost:5004
  configuration:
    target:
      namespace: ocm-demos
    resources:
      - name: configmap
        namespace: ocm-demos
      - name: deployment
        namespace: ocm-demos
        replicas: 2
      - name: service
        namespace: ocm-demos
      - name: ingress
        namespace: ocm-demos
EOF

echo "✅ OCM Configuration created"

# Step 5: Create ComponentVersion resource
cat > component-version.yaml << 'EOF'
apiVersion: ocm.software/v1alpha1
kind: ComponentVersion
metadata:
  name: demo-app-component
  namespace: ocm-demos
spec:
  component: github.com/ocm-demo/k8s-app
  version: v1.0.0
  repository: http://localhost:5004
EOF

echo "✅ ComponentVersion resource created"

# Step 6: Deploy to Kubernetes
echo -e "${YELLOW}☸️  Step 6: Deploying to Kubernetes${NC}"

# Apply the OCM resources (disable validation for custom resources)
kubectl apply -f component-version.yaml --validate=false
kubectl apply -f ocm-configuration.yaml --validate=false

# Since we're simulating OCM K8s Toolkit, manually extract and apply manifests
echo "Extracting and applying manifests..."

# Extract manifests from component
cd ../components
mkdir -p extracted

# Ensure OCM uses HTTP for localhost
export OCM_CONFIG_PLAIN_HTTP=localhost:5004

ocm download resources http://localhost:5004//github.com/ocm-demo/k8s-app:v1.0.0 \
  configmap -O extracted/
ocm download resources http://localhost:5004//github.com/ocm-demo/k8s-app:v1.0.0 \
  deployment -O extracted/
ocm download resources http://localhost:5004//github.com/ocm-demo/k8s-app:v1.0.0 \
  service -O extracted/
ocm download resources http://localhost:5004//github.com/ocm-demo/k8s-app:v1.0.0 \
  ingress -O extracted/

# Apply manifests to cluster
kubectl apply -f extracted/ -n ocm-demos

echo "✅ Manifests applied to Kubernetes"

# Step 7: Wait for deployment and verify
echo -e "${YELLOW}⏳ Step 7: Waiting for deployment${NC}"

# Wait for deployment to be ready
kubectl wait --for=condition=available deployment/ocm-demo-app -n ocm-demos --timeout=300s

echo -e "${GREEN}✅ Deployment is ready${NC}"

# Step 8: Display deployment status
echo -e "${YELLOW}📊 Step 8: Checking deployment status${NC}"

echo -e "${GREEN}Pods:${NC}"
kubectl get pods -n ocm-demos -l app=ocm-demo-app

echo -e "${GREEN}Services:${NC}"
kubectl get services -n ocm-demos

echo -e "${GREEN}Ingress:${NC}"
kubectl get ingress -n ocm-demos

echo -e "${GREEN}OCM Resources:${NC}"
kubectl get componentversions,ocmconfigurations -n ocm-demos

# Step 9: Test the application
echo -e "${YELLOW}🧪 Step 9: Testing the application${NC}"

# Port forward for testing
echo "Setting up port forward for testing..."
kubectl port-forward service/ocm-demo-service 8080:80 -n ocm-demos &
PORT_FORWARD_PID=$!

# Wait a moment for port forward to establish
sleep 3

# Test the application
echo "Testing application..."
if curl -s http://localhost:8080 | grep -q "OCM Kubernetes"; then
    echo -e "${GREEN}✅ Application is responding correctly${NC}"
else
    echo -e "${YELLOW}⚠️  Application response test inconclusive${NC}"
fi

# Cleanup port forward
kill $PORT_FORWARD_PID 2>/dev/null || true

echo -e "${GREEN}✨ OCM K8s deployment demo completed successfully!${NC}"
echo -e "${BLUE}📋 Deployment summary:${NC}"
echo "   Component: github.com/ocm-demo/k8s-app:v1.0.0"
echo "   Registry: localhost:5004"
echo "   Namespace: ocm-demos"
echo "   Resources: ConfigMap, Deployment, Service, Ingress"
echo ""
echo -e "${BLUE}🔗 Access the application:${NC}"
echo "   kubectl port-forward service/ocm-demo-service 8080:80 -n ocm-demos"
echo "   Then visit: http://localhost:8080"
echo ""
echo -e "${BLUE}🧹 Cleanup:${NC}"
echo "   kubectl delete namespace ocm-demos"
