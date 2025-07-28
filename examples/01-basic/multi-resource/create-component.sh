#!/bin/bash

# Create OCM Component with Multiple Resources
# Demonstrates packaging different types of resources in a single component

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$SCRIPT_DIR/work"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Creating Multi-Resource OCM Component${NC}"

# Clean and create work directory
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"/{config,scripts,docs}
cd "$WORK_DIR"

# Step 1: Create multiple resources
echo -e "${YELLOW}📝 Step 1: Creating multiple resources${NC}"

# Configuration file
cat > config/app.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: myapp-config
  namespace: default
data:
  app.properties: |
    app.name=MyApp
    app.version=v1.0.0
    database.url=postgresql://localhost:5432/myapp
    logging.level=INFO
EOF

# Deployment script
cat > scripts/deploy.sh << 'EOF'
#!/bin/bash
set -euo pipefail

echo "Deploying MyApp v1.0.0..."
kubectl apply -f ../config/app.yaml

echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=myapp --timeout=300s

echo "Deployment completed successfully!"
EOF
chmod +x scripts/deploy.sh

# Documentation
cat > docs/README.md << 'EOF'
# MyApp

A sample application demonstrating OCM multi-resource components.

## Components

- **Configuration**: Kubernetes ConfigMap for application settings
- **Scripts**: Deployment automation scripts
- **Documentation**: Usage instructions and API reference

## Deployment

Run the deployment script:
```bash
./scripts/deploy.sh
```

## Configuration

Edit `config/app.yaml` to customize application settings.
EOF

echo "✅ Created multiple resource files"

# Step 2: Create component with multiple resources
echo -e "${YELLOW}📦 Step 2: Creating OCM component with multiple resources${NC}"

# Initialize component
ocm create componentarchive github.com/ocm-demo/myapp v1.0.0 \
  --provider ocm-demo \
  --file myapp-component

# Add configuration resource
ocm add resources myapp-component \
  --name app-config \
  --type kubernetesManifest \
  --version v1.0.0 \
  --inputType file \
  --inputPath config/app.yaml

# Add deployment script
ocm add resources myapp-component \
  --name deployment-script \
  --type executable \
  --version v1.0.0 \
  --inputType file \
  --inputPath scripts/deploy.sh

# Add documentation
ocm add resources myapp-component \
  --name documentation \
  --type plainText \
  --version v1.0.0 \
  --inputType file \
  --inputPath docs/README.md

echo "✅ Created multi-resource component"

# Step 3: Add labels and metadata
echo -e "${YELLOW}🏷️  Step 3: Adding component metadata${NC}"

# Add component labels (using OCM CLI directly on the archive)
cat > component-labels.yaml << 'EOF'
labels:
  - name: demo.ocm.software/category
    value: sample-application
  - name: demo.ocm.software/complexity
    value: intermediate
  - name: demo.ocm.software/resources
    value: "3"
EOF

echo "✅ Component labels defined"

# Step 4: Inspect the component
echo -e "${YELLOW}🔍 Step 4: Inspecting the multi-resource component${NC}"

echo -e "${GREEN}Component overview:${NC}"
ocm get componentversions myapp-component

echo -e "${GREEN}All resources:${NC}"
ocm get resources myapp-component

echo -e "${GREEN}Detailed resource information:${NC}"
ocm get resources myapp-component -o yaml

# Step 5: Extract resources (demonstrate consumption)
echo -e "${YELLOW}📤 Step 5: Demonstrating resource extraction${NC}"
mkdir -p extracted

echo "Extracting configuration file:"
ocm download resources myapp-component app-config -O extracted/app.yaml
ls -la extracted/

echo "Extracting deployment script:"
ocm download resources myapp-component deployment-script -O extracted/deploy.sh
ls -la extracted/

echo "✅ Resources extracted successfully"

# Step 6: Push to registry if available
if curl -s http://localhost:5001/v2/ > /dev/null 2>&1; then
    echo -e "${YELLOW}🚀 Step 6: Pushing to local registry${NC}"
    ocm transfer componentarchive myapp-component http://localhost:5001
    echo "✅ Multi-resource component pushed to localhost:5001"
    
    echo -e "${GREEN}Verifying in registry:${NC}"
    ocm get resources http://localhost:5001//github.com/ocm-demo/myapp:v1.0.0
else
    echo -e "${YELLOW}⚠️  Local registry not available. Skipping push step.${NC}"
fi

echo -e "${GREEN}✨ Multi-resource component created successfully!${NC}"
echo -e "${BLUE}📁 Check the work directory: $WORK_DIR${NC}"
echo -e "${BLUE}📋 Resources created:${NC}"
echo "   - Configuration: config/app.yaml"
echo "   - Scripts: scripts/deploy.sh" 
echo "   - Documentation: docs/README.md"
