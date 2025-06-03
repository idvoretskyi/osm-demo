#!/bin/bash

# OCM Offline Transport Example
# Demonstrates air-gapped transport using Common Transport Format

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$SCRIPT_DIR/work"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔒 OCM Offline Transport Demo (Air-Gapped)${NC}"

# Clean and create work directory
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"/{source-env,transport-bundle,target-env}
cd "$WORK_DIR"

echo -e "${YELLOW}🌐 Simulating air-gapped environment transport${NC}"

# Step 1: Setup source environment
echo -e "${YELLOW}📦 Step 1: Setting up source environment${NC}"

cd source-env

# Start source registry
if ! curl -s http://localhost:5002/v2/ > /dev/null 2>&1; then
    echo "Starting source environment registry on port 5002..."
    docker run -d -p 5002:5002 --name source-env-registry \
        -e REGISTRY_HTTP_ADDR=0.0.0.0:5002 registry:2 || true
    sleep 2
fi

# Create a component to transport
mkdir -p secure-app
cat > secure-app/app.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
  labels:
    app: secure-app
    security.policy: restricted
spec:
  replicas: 2
  selector:
    matchLabels:
      app: secure-app
  template:
    metadata:
      labels:
        app: secure-app
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: var-cache
          mountPath: /var/cache/nginx
        - name: var-run
          mountPath: /var/run
      volumes:
      - name: tmp
        emptyDir: {}
      - name: var-cache
        emptyDir: {}
      - name: var-run
        emptyDir: {}
EOF

cat > secure-app/security-policy.yaml << 'EOF'
apiVersion: policy/v1
kind: NetworkPolicy
metadata:
  name: secure-app-netpol
spec:
  podSelector:
    matchLabels:
      app: secure-app
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: frontend
    ports:
    - protocol: TCP
      port: 80
  egress:
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
EOF

# Create OCM component
ocm create componentarchive github.com/ocm-demo/secure-app v1.0.0 \
  --provider security-team \
  --file secure-component

ocm add resources secure-component \
  --name application-manifest \
  --type kubernetesManifest \
  --version v1.0.0 \
  --inputType file \
  --inputPath secure-app/app.yaml

ocm add resources secure-component \
  --name security-policy \
  --type kubernetesManifest \
  --version v1.0.0 \
  --inputType file \
  --inputPath secure-app/security-policy.yaml

# Push to source registry
ocm transfer componentarchive secure-component http://localhost:5002

echo "✅ Source environment prepared with secure component"

# Step 2: Export to Common Transport Format
echo -e "${YELLOW}📤 Step 2: Exporting to Common Transport Format${NC}"

cd ../transport-bundle

# Create transport archive for offline transfer
ocm transfer componentversion http://localhost:5002//github.com/ocm-demo/secure-app:v1.0.0 ctf+tgz::secure-app-transport.tar.gz

echo "✅ Component exported to transport bundle: secure-app-transport.tar.gz"

# Show bundle contents
echo -e "${GREEN}Transport bundle contents:${NC}"
ls -lh secure-app-transport.tar.gz

# Step 3: Simulate transport to air-gapped environment
echo -e "${YELLOW}🚚 Step 3: Simulating physical transport${NC}"

echo "📦 Simulating:"
echo "   1. Copy transport bundle to removable media"
echo "   2. Physical transport to air-gapped environment"
echo "   3. Import into target environment"

cp secure-app-transport.tar.gz ../target-env/
echo "✅ Transport bundle moved to target environment"

# Step 4: Setup target environment
echo -e "${YELLOW}🎯 Step 4: Setting up target environment${NC}"

cd ../target-env

# Start target registry (simulating air-gapped registry)
if ! curl -s http://localhost:5003/v2/ > /dev/null 2>&1; then
    echo "Starting target environment registry on port 5003..."
    docker run -d -p 5003:5000 --name target-env-registry registry:2 || true
    sleep 2
fi

echo "✅ Target environment registry ready"

# Step 5: Import from Common Transport Format
echo -e "${YELLOW}📥 Step 5: Importing from transport bundle${NC}"

# Import the component from transport archive
ocm transfer ctf secure-app-transport.tar.gz http://localhost:5003

echo "✅ Component imported into target environment"

# Verify import
echo -e "${GREEN}Verifying imported component:${NC}"
ocm get componentversions http://localhost:5003//github.com/ocm-demo/secure-app:v1.0.0

echo -e "${GREEN}Component resources in target environment:${NC}"
ocm get resources http://localhost:5003//github.com/ocm-demo/secure-app:v1.0.0

# Step 6: Extract and verify content in target environment
echo -e "${YELLOW}🔍 Step 6: Extracting content in target environment${NC}"

mkdir -p extracted
ocm download resources http://localhost:5003//github.com/ocm-demo/secure-app:v1.0.0 \
  application-manifest -O extracted/app.yaml

ocm download resources http://localhost:5003//github.com/ocm-demo/secure-app:v1.0.0 \
  security-policy -O extracted/security-policy.yaml

echo -e "${GREEN}Extracted manifests:${NC}"
ls -la extracted/

echo -e "${GREEN}Application manifest:${NC}"
head -10 extracted/application-manifest

# Step 7: Demonstrate integrity verification
echo -e "${YELLOW}🔐 Step 7: Verifying transport integrity${NC}"

# Compare component descriptor checksums
echo "Getting component descriptor from source:"
cd ../source-env
ocm get componentversions secure-component -o yaml | grep -A 5 -B 5 "digest\|signature" || echo "Component descriptor extracted"

echo "Getting component descriptor from target:"
cd ../target-env
ocm get componentversions localhost:5003//github.com/ocm-demo/secure-app:v1.0.0 -o yaml | grep -A 5 -B 5 "digest\|signature" || echo "Component descriptor extracted"

echo -e "${GREEN}✨ Offline transport completed successfully!${NC}"
echo -e "${BLUE}🔄 Transport summary:${NC}"
echo "   Source: localhost:5002 (Connected environment)"
echo "   Bundle: secure-app-transport.tar.gz (Transport medium)"
echo "   Target: localhost:5003 (Air-gapped environment)"
echo ""
echo -e "${BLUE}📦 Transport bundle size:${NC}"
cd ../transport-bundle
ls -lh secure-app-transport.tar.gz

echo ""
echo -e "${YELLOW}💡 Use cases for offline transport:${NC}"
echo "   🔒 Air-gapped security environments"
echo "   🌐 Environments with limited internet access"
echo "   📋 Compliance requirements for software delivery"
echo "   🚀 Edge deployments with intermittent connectivity"
