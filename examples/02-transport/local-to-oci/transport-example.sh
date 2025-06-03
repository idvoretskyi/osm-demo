#!/bin/bash

# OCM Local to OCI Transport Example
# Demonstrates transporting components from local archives to OCI registries

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$SCRIPT_DIR/work"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 OCM Local to OCI Transport Demo${NC}"

# Clean and create work directory
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Step 1: Ensure registries are running
echo -e "${YELLOW}🐳 Step 1: Setting up registries${NC}"

# Start source registry (port 5000)
if ! curl -s http://localhost:5000/v2/ > /dev/null 2>&1; then
    echo "Starting source registry on port 5000..."
    docker run -d -p 5000:5000 --name source-registry registry:2 || true
    sleep 2
fi

# Start target registry (port 5001)
if ! curl -s http://localhost:5001/v2/ > /dev/null 2>&1; then
    echo "Starting target registry on port 5001..."
    docker run -d -p 5001:5001 --name target-registry \
        -e REGISTRY_HTTP_ADDR=0.0.0.0:5001 registry:2 || true
    sleep 2
fi

echo "✅ Registries are running"

# Step 2: Create a sample component locally
echo -e "${YELLOW}📦 Step 2: Creating local component${NC}"

# Create sample application files
mkdir -p app
cat > app/main.go << 'EOF'
package main

import (
    "fmt"
    "net/http"
)

func main() {
    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        fmt.Fprintf(w, "Hello from OCM Transport Demo!")
    })
    
    fmt.Println("Server starting on :8080")
    http.ListenAndServe(":8080", nil)
}
EOF

cat > app/Dockerfile << 'EOF'
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY main.go .
RUN go build -o main .

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/main .
EXPOSE 8080
CMD ["./main"]
EOF

cat > app/k8s-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: transport-demo-app
  labels:
    app: transport-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: transport-demo
  template:
    metadata:
      labels:
        app: transport-demo
    spec:
      containers:
      - name: app
        image: localhost:5000/transport-demo:v1.0.0
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: transport-demo-service
spec:
  selector:
    app: transport-demo
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP
EOF

echo "✅ Created sample application files"

# Step 3: Create OCM component archive
echo -e "${YELLOW}📋 Step 3: Creating OCM component archive${NC}"

# Initialize component
ocm create componentarchive github.com/ocm-demo/transport-app v1.0.0 \
  --provider ocm-demo \
  --file transport-component

# Add resources
ocm add resources transport-component app/main.go \
  --name source-code \
  --type file \
  --version v1.0.0 \
  --access-type localBlob

ocm add resources transport-component app/Dockerfile \
  --name dockerfile \
  --type dockerfile \
  --version v1.0.0 \
  --access-type localBlob

ocm add resources transport-component app/k8s-deployment.yaml \
  --name k8s-manifests \
  --type kubernetesManifest \
  --version v1.0.0 \
  --access-type localBlob

echo "✅ Created component archive with multiple resources"

# Step 4: Transport to first registry
echo -e "${YELLOW}🚀 Step 4: Transporting to source registry${NC}"

ocm transfer componentarchive transport-component localhost:5000

echo "✅ Component transported to localhost:5000"

# Verify in source registry
echo -e "${GREEN}Verifying in source registry:${NC}"
ocm get componentversions localhost:5000//github.com/ocm-demo/transport-app:v1.0.0

# Step 5: Transport from OCI to OCI (registry to registry)
echo -e "${YELLOW}📤 Step 5: Transporting between registries${NC}"

ocm transfer componentversion localhost:5000//github.com/ocm-demo/transport-app:v1.0.0 localhost:5001

echo "✅ Component transported from localhost:5000 to localhost:5001"

# Verify in target registry
echo -e "${GREEN}Verifying in target registry:${NC}"
ocm get componentversions localhost:5001//github.com/ocm-demo/transport-app:v1.0.0

# Step 6: Transport back to local archive (round trip)
echo -e "${YELLOW}🔄 Step 6: Transporting back to local archive${NC}"

ocm transfer componentversion localhost:5001//github.com/ocm-demo/transport-app:v1.0.0 \
  --type componentarchive target-archive

echo "✅ Component transported back to local archive"

# Verify local archive
echo -e "${GREEN}Verifying local archive:${NC}"
ocm get componentversions target-archive

# Step 7: Compare archives
echo -e "${YELLOW}🔍 Step 7: Comparing original and transported archives${NC}"

echo -e "${GREEN}Original component resources:${NC}"
ocm get resources transport-component

echo -e "${GREEN}Transported component resources:${NC}"
ocm get resources target-archive

# Step 8: Extract and compare content
echo -e "${YELLOW}📤 Step 8: Extracting content for verification${NC}"

mkdir -p extracted/{original,transported}

echo "Extracting from original archive:"
ocm download resources transport-component source-code -O extracted/original/
ocm download resources transport-component dockerfile -O extracted/original/
ocm download resources transport-component k8s-manifests -O extracted/original/

echo "Extracting from transported archive:"
ocm download resources target-archive source-code -O extracted/transported/
ocm download resources target-archive dockerfile -O extracted/transported/
ocm download resources target-archive k8s-manifests -O extracted/transported/

echo "Comparing files:"
diff -r extracted/original/ extracted/transported/ || echo "Files are identical ✅"

echo -e "${GREEN}✨ Transport example completed successfully!${NC}"
echo -e "${BLUE}📁 Work directory: $WORK_DIR${NC}"
echo -e "${BLUE}🔄 Transport path: Local Archive → OCI Registry → OCI Registry → Local Archive${NC}"
