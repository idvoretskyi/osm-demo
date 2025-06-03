#!/bin/bash

# Setup Kubernetes cluster for OCM demos
# Creates a kind cluster with necessary components for OCM K8s integration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}☸️  Setting up Kubernetes cluster for OCM demos${NC}"

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

# Create or recreate the cluster
echo -e "${YELLOW}🚀 Creating kind cluster...${NC}"

# Delete existing cluster if it exists
if kind get clusters | grep -q ocm-demo; then
    echo "Deleting existing ocm-demo cluster..."
    kind delete cluster --name ocm-demo
fi

# Create new cluster
kind create cluster --config kind-config.yaml

echo -e "${GREEN}✅ Kind cluster created${NC}"

# Wait for cluster to be ready
echo -e "${YELLOW}⏳ Waiting for cluster to be ready...${NC}"
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Install NGINX Ingress Controller
echo -e "${YELLOW}🌐 Installing NGINX Ingress Controller...${NC}"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for ingress controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

echo -e "${GREEN}✅ NGINX Ingress Controller installed${NC}"

# Install Flux
echo -e "${YELLOW}🔄 Installing Flux...${NC}"

# Check if Flux is already installed
if kubectl get namespace flux-system &> /dev/null; then
    echo "Flux already installed, skipping..."
else
    flux install
    kubectl wait --for=condition=Ready pods --all -n flux-system --timeout=300s
fi

echo -e "${GREEN}✅ Flux installed${NC}"

# Create namespace for OCM demos
echo -e "${YELLOW}📦 Creating OCM demo namespace...${NC}"
kubectl create namespace ocm-demos || echo "Namespace already exists"

# Install OCM K8s Toolkit (placeholder - would be actual install in real scenario)
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

kubectl apply -f ocm-crds.yaml

echo -e "${GREEN}✅ OCM CRDs installed${NC}"

# Create local registry access
echo -e "${YELLOW}🐳 Setting up local registry access...${NC}"

# Create configmap for local registry access
kubectl create configmap registry-config \
  --from-literal=registry-url=host.docker.internal:5004 \
  -n ocm-demos || echo "ConfigMap already exists"

echo -e "${GREEN}✅ Registry configuration created${NC}"

# Install metrics server (for HPA if needed)
echo -e "${YELLOW}📊 Installing metrics server...${NC}"
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch metrics server for kind
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

echo -e "${GREEN}✅ Metrics server installed${NC}"

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

echo -e "${GREEN}✨ Kubernetes cluster setup completed!${NC}"
echo -e "${BLUE}🔗 Cluster details:${NC}"
echo "   Cluster name: ocm-demo"
echo "   Nodes: 1 control-plane + 2 workers"
echo "   Ingress: NGINX (ports 8080, 8443)"
echo "   GitOps: Flux installed"
echo "   Registry: localhost:5004 accessible"
echo "   Namespace: ocm-demos"
echo ""
echo -e "${BLUE}🚀 Ready for OCM deployment examples!${NC}"
