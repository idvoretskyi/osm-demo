#!/bin/bash

# Create OCM Hello World Component
# This script demonstrates creating a basic OCM component with a simple text resource

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$SCRIPT_DIR/work"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Creating OCM Hello World Component${NC}"

# Clean and create work directory
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Step 1: Create the hello world resource
echo -e "${YELLOW}📝 Step 1: Creating hello world resource${NC}"
cat > hello.txt << 'EOF'
Hello from OCM!

This is a simple text resource packaged as an OCM component.
It demonstrates the basic building blocks of the Open Component Model.

Component: hello-world
Version: v1.0.0
Created: $(date)
EOF

echo "✅ Created hello.txt resource"

# Step 2: Create component descriptor
echo -e "${YELLOW}📋 Step 2: Creating component descriptor${NC}"
cat > component-descriptor.yaml << 'EOF'
apiVersion: ocm.software/v3alpha1
kind: ComponentDescriptor
metadata:
  name: github.com/ocm-demo/hello-world
  version: v1.0.0
  provider:
    name: ocm-demo
    labels:
      - name: demo.ocm.software/purpose
        value: learning
spec:
  repositories:
    - name: default
      type: ociRegistry
      baseUrl: localhost:5000
  resources:
    - name: hello-message
      type: plainText
      version: v1.0.0
      access:
        type: localBlob
        localReference: hello.txt
        mediaType: text/plain
      labels:
        - name: demo.ocm.software/description
          value: A simple hello world message
EOF

echo "✅ Created component descriptor"

# Step 3: Create OCM component archive
echo -e "${YELLOW}📦 Step 3: Creating OCM component archive${NC}"

# Initialize OCM component
ocm create componentarchive github.com/ocm-demo/hello-world v1.0.0 \
  --provider ocm-demo \
  --file component-archive

# Add the resource with correct syntax
ocm add resources component-archive \
  --name hello-message \
  --type plainText \
  --version v1.0.0 \
  --inputType file \
  --inputPath hello.txt

echo "✅ Created OCM component archive"

# Step 4: Inspect the component
echo -e "${YELLOW}🔍 Step 4: Inspecting the component${NC}"
echo -e "${GREEN}Component descriptor:${NC}"
ocm get componentversions component-archive

echo -e "${GREEN}Component resources:${NC}"
ocm get resources component-archive

# Step 5: Transfer to local registry (if available)
if curl -s http://localhost:5001/v2/ > /dev/null 2>&1; then
    echo -e "${YELLOW}🚀 Step 5: Pushing to local registry${NC}"
    ocm transfer componentarchive component-archive http://localhost:5001
    echo "✅ Component pushed to localhost:5001"
    
    echo -e "${GREEN}Verifying in registry:${NC}"
    ocm get componentversions http://localhost:5001//github.com/ocm-demo/hello-world:v1.0.0
else
    echo -e "${YELLOW}⚠️  Local registry not available. Skipping push step.${NC}"
    echo "   Start registry with: docker run -d -p 5001:5000 --name registry registry:2"
fi

echo -e "${GREEN}✨ Hello World component created successfully!${NC}"
echo -e "${BLUE}📁 Check the work directory for generated files: $WORK_DIR${NC}"
