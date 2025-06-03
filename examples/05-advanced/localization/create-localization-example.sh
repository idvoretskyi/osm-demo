#!/bin/bash

# OCM Resource Localization Example
# Demonstrates customizing components for different environments

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$SCRIPT_DIR/work"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🌍 OCM Resource Localization Demo${NC}"

# Clean and create work directory
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"/{base,dev,staging,prod}
cd "$WORK_DIR"

# Step 1: Create base application component
echo -e "${YELLOW}📦 Step 1: Creating base application component${NC}"

# Create base application
cat > base/app.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  labels:
    app: web-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: app
        image: nginx:1.21
        ports:
        - containerPort: 80
        env:
        - name: ENVIRONMENT
          value: "base"
        - name: LOG_LEVEL
          value: "info"
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: web-app-service
spec:
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

cat > base/config.json << 'EOF'
{
  "app": {
    "name": "web-app",
    "version": "1.0.0",
    "environment": "base",
    "features": {
      "authentication": true,
      "logging": true,
      "monitoring": false,
      "debug": false
    },
    "database": {
      "host": "localhost",
      "port": 5432,
      "name": "webapp_db"
    },
    "cache": {
      "enabled": false,
      "ttl": 300
    }
  }
}
EOF

# Create base component
ocm create componentarchive acme.corp/web-app v1.0.0 \
  --provider acme-corp \
  --file base-component

ocm add resources base-component \
  --name k8s-manifests \
  --type kubernetesManifest \
  --version v1.0.0 \
  --inputType file \
  --inputPath base/app.yaml

ocm add resources base-component \
  --name app-config \
  --type json \
  --version v1.0.0 \
  --inputType file \
  --inputPath base/config.json

echo "✅ Created base component"

# Step 2: Create environment-specific localizations
echo -e "${YELLOW}🔧 Step 2: Creating environment-specific localizations${NC}"

# Development environment
cat > dev/app.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  labels:
    app: web-app
    environment: development
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
        environment: development
    spec:
      containers:
      - name: app
        image: nginx:1.21
        ports:
        - containerPort: 80
        env:
        - name: ENVIRONMENT
          value: "development"
        - name: LOG_LEVEL
          value: "debug"
        - name: DEBUG_MODE
          value: "true"
        resources:
          requests:
            memory: "32Mi"
            cpu: "100m"
          limits:
            memory: "64Mi"
            cpu: "200m"
---
apiVersion: v1
kind: Service
metadata:
  name: web-app-service
  labels:
    environment: development
spec:
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
  type: NodePort
EOF

cat > dev/config.json << 'EOF'
{
  "app": {
    "name": "web-app",
    "version": "1.0.0",
    "environment": "development",
    "features": {
      "authentication": false,
      "logging": true,
      "monitoring": true,
      "debug": true
    },
    "database": {
      "host": "dev-db.local",
      "port": 5432,
      "name": "webapp_dev"
    },
    "cache": {
      "enabled": true,
      "ttl": 60
    }
  }
}
EOF

# Production environment
cat > prod/app.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  labels:
    app: web-app
    environment: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
        environment: production
    spec:
      containers:
      - name: app
        image: nginx:1.21
        ports:
        - containerPort: 80
        env:
        - name: ENVIRONMENT
          value: "production"
        - name: LOG_LEVEL
          value: "warn"
        resources:
          requests:
            memory: "128Mi"
            cpu: "500m"
          limits:
            memory: "256Mi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 30
        readinessProbe:
          httpGet:
            path: /ready
            port: 80
          initialDelaySeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: web-app-service
  labels:
    environment: production
spec:
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
EOF

cat > prod/config.json << 'EOF'
{
  "app": {
    "name": "web-app",
    "version": "1.0.0",
    "environment": "production",
    "features": {
      "authentication": true,
      "logging": true,
      "monitoring": true,
      "debug": false
    },
    "database": {
      "host": "prod-db.cluster.local",
      "port": 5432,
      "name": "webapp_prod"
    },
    "cache": {
      "enabled": true,
      "ttl": 3600
    }
  }
}
EOF

echo "✅ Created environment-specific configurations"

# Step 3: Create localized components
echo -e "${YELLOW}🎯 Step 3: Creating localized components${NC}"

# Development localization
ocm create componentarchive acme.corp/web-app-dev v1.0.0 \
  --provider acme-corp \
  --file dev-component

ocm add resources dev-component \
  --name k8s-manifests \
  --type kubernetesManifest \
  --version v1.0.0 \
  --inputType file \
  --inputPath dev/app.yaml

ocm add resources dev-component \
  --name app-config \
  --type json \
  --version v1.0.0 \
  --inputType file \
  --inputPath dev/config.json

# Add localization metadata
cat > dev-labels.yaml << 'EOF'
labels:
  - name: environment
    value: development
  - name: deployment.type
    value: single-replica
  - name: security.level
    value: low
  - name: monitoring.enabled
    value: "true"
EOF

echo "✅ Created development localization"

# Production localization
ocm create componentarchive acme.corp/web-app-prod v1.0.0 \
  --provider acme-corp \
  --file prod-component

ocm add resources prod-component \
  --name k8s-manifests \
  --type kubernetesManifest \
  --version v1.0.0 \
  --inputType file \
  --inputPath prod/app.yaml

ocm add resources prod-component \
  --name app-config \
  --type json \
  --version v1.0.0 \
  --inputType file \
  --inputPath prod/config.json

cat > prod-labels.yaml << 'EOF'
labels:
  - name: environment
    value: production
  - name: deployment.type
    value: high-availability
  - name: security.level
    value: high
  - name: monitoring.enabled
    value: "true"
EOF

echo "✅ Created production localization"

# Step 4: Compare configurations
echo -e "${YELLOW}🔍 Step 4: Comparing configurations${NC}"

echo -e "${GREEN}Base component resources:${NC}"
ocm get resources base-component

echo -e "${GREEN}Development variant resources:${NC}"
ocm get resources dev-component

echo -e "${GREEN}Production variant resources:${NC}"
ocm get resources prod-component

# Extract and compare configurations
mkdir -p extracted/{base,dev,prod}

echo -e "${GREEN}Extracting configurations for comparison:${NC}"

ocm download resources base-component app-config -O extracted/base/config.json
ocm download resources dev-component app-config -O extracted/dev/config.json
ocm download resources prod-component app-config -O extracted/prod/config.json

echo "Development vs Base differences:"
diff extracted/base/config.json extracted/dev/config.json || echo "✅ Differences identified"

echo ""
echo "Production vs Base differences:"
diff extracted/base/config.json extracted/prod/config.json || echo "✅ Differences identified"

# Step 5: Push localized components to registry
if curl -s http://localhost:5001/v2/ > /dev/null 2>&1; then
    echo -e "${YELLOW}🚀 Step 5: Pushing localized components to registry${NC}"
    
    ocm transfer componentarchive base-component http://localhost:5001
    echo "✅ Base component pushed"
    
    ocm transfer componentarchive dev-component http://localhost:5001
    echo "✅ Development variant pushed"
    
    ocm transfer componentarchive prod-component http://localhost:5001
    echo "✅ Production variant pushed"
    
    echo -e "${GREEN}Verifying localized components in registry:${NC}"
    ocm get componentversions http://localhost:5001//acme.corp/web-app:v1.0.0
    ocm get componentversions http://localhost:5001//acme.corp/web-app-dev:v1.0.0
    ocm get componentversions http://localhost:5001//acme.corp/web-app-prod:v1.0.0
else
    echo -e "${YELLOW}⚠️  Local registry not available. Skipping push step.${NC}"
fi

echo -e "${GREEN}✨ Resource localization example completed!${NC}"
echo -e "${BLUE}📁 Work directory: $WORK_DIR${NC}"
echo -e "${BLUE}🌍 Localization concepts demonstrated:${NC}"
echo "   • Environment-specific resource variants"
echo "   • Configuration customization patterns"
echo "   • Multi-environment deployment strategies"
echo "   • Resource adaptation for different contexts"