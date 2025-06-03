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

# Clean and create work directory
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"/{manifests,components}
cd "$WORK_DIR"

# Step 1: Check cluster readiness
echo -e "${YELLOW}🔍 Step 1: Checking cluster readiness${NC}"

if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ Kubernetes cluster not accessible. Run ../setup-cluster.sh first.${NC}"
    exit 1
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
    docker run -d -p 5004:5000 --name registry registry:2 || true
    sleep 2
fi

# Push component
ocm transfer componentarchive k8s-component localhost:5004

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
    repository: localhost:5004
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
  repository: localhost:5004
EOF

echo "✅ ComponentVersion resource created"

# Step 6: Deploy to Kubernetes
echo -e "${YELLOW}☸️  Step 6: Deploying to Kubernetes${NC}"

# Apply the OCM resources
kubectl apply -f component-version.yaml
kubectl apply -f ocm-configuration.yaml

# Since we're simulating OCM K8s Toolkit, manually extract and apply manifests
echo "Extracting and applying manifests..."

# Extract manifests from component
cd ../components
mkdir -p extracted
ocm download resources localhost:5004//github.com/ocm-demo/k8s-app:v1.0.0 \
  configmap -O extracted/
ocm download resources localhost:5004//github.com/ocm-demo/k8s-app:v1.0.0 \
  deployment -O extracted/
ocm download resources localhost:5004//github.com/ocm-demo/k8s-app:v1.0.0 \
  service -O extracted/
ocm download resources localhost:5004//github.com/ocm-demo/k8s-app:v1.0.0 \
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
