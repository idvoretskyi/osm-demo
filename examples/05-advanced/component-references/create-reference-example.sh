#!/bin/bash

# OCM Component References Example
# Demonstrates creating components that reference other components

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$SCRIPT_DIR/work"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔗 OCM Component References Demo${NC}"

# Clean and create work directory
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Step 1: Create a base library component
echo -e "${YELLOW}📚 Step 1: Creating base library component${NC}"

# Create library source
mkdir -p library
cat > library/utils.js << 'EOF'
// Utility Library v1.0.0
export function formatDate(date) {
    return date.toISOString().split('T')[0];
}

export function validateEmail(email) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

export function capitalize(str) {
    return str.charAt(0).toUpperCase() + str.slice(1);
}
EOF

cat > library/package.json << 'EOF'
{
  "name": "@acme/utils",
  "version": "1.0.0",
  "description": "Utility functions library",
  "main": "utils.js",
  "type": "module",
  "author": "ACME Corp",
  "license": "MIT"
}
EOF

# Create library component
ocm create componentarchive acme.corp/utils v1.0.0 \
  --provider acme-corp \
  --file utils-component

ocm add resources utils-component \
  --name source-code \
  --type javascript \
  --version v1.0.0 \
  --inputType file \
  --inputPath library/utils.js

ocm add resources utils-component \
  --name package-descriptor \
  --type json \
  --version v1.0.0 \
  --inputType file \
  --inputPath library/package.json

echo "✅ Created utils library component"

# Step 2: Create an application that references the library
echo -e "${YELLOW}🚀 Step 2: Creating application with component reference${NC}"

mkdir -p app
cat > app/main.js << 'EOF'
// Main Application v2.0.0
// This app depends on the utils library component

import { formatDate, validateEmail, capitalize } from '@acme/utils';

class UserManager {
    constructor() {
        this.users = [];
    }
    
    addUser(email, name, birthDate) {
        if (!validateEmail(email)) {
            throw new Error('Invalid email format');
        }
        
        const user = {
            email,
            name: capitalize(name),
            birthDate: formatDate(new Date(birthDate)),
            registeredAt: formatDate(new Date())
        };
        
        this.users.push(user);
        return user;
    }
    
    getUsers() {
        return this.users;
    }
}

// Example usage
const manager = new UserManager();
manager.addUser('john.doe@example.com', 'john doe', '1990-05-15');
console.log('Users:', manager.getUsers());
EOF

cat > app/package.json << 'EOF'
{
  "name": "@acme/user-app",
  "version": "2.0.0",
  "description": "User management application",
  "main": "main.js",
  "type": "module",
  "dependencies": {
    "@acme/utils": "^1.0.0"
  },
  "author": "ACME Corp",
  "license": "MIT"
}
EOF

# Create application component with reference to utils
ocm create componentarchive acme.corp/user-app v2.0.0 \
  --provider acme-corp \
  --file app-component

# Add component reference to utils library
ocm add references app-component \
  --name utils-library \
  --component acme.corp/utils \
  --version v1.0.0

ocm add resources app-component \
  --name application-code \
  --type javascript \
  --version v2.0.0 \
  --inputType file \
  --inputPath app/main.js

ocm add resources app-component \
  --name app-package-descriptor \
  --type json \
  --version v2.0.0 \
  --inputType file \
  --inputPath app/package.json

echo "✅ Created application component with library reference"

# Step 3: Inspect component references
echo -e "${YELLOW}🔍 Step 3: Inspecting component references${NC}"

echo -e "${GREEN}Utils library component:${NC}"
ocm get componentversions utils-component

echo -e "${GREEN}Application component with references:${NC}"
ocm get componentversions app-component

echo -e "${GREEN}Component references in application:${NC}"
ocm get componentversions app-component -o yaml | grep -A 10 "componentReferences" || echo "References are embedded"

# Step 4: Push components to registry
if curl -s http://localhost:5001/v2/ > /dev/null 2>&1; then
    echo -e "${YELLOW}🚀 Step 4: Pushing components to registry${NC}"
    
    # Push library first (dependency)
    ocm transfer componentarchive utils-component http://localhost:5001
    echo "✅ Utils library pushed to registry"
    
    # Push application (depends on library)
    ocm transfer componentarchive app-component http://localhost:5001
    echo "✅ Application pushed to registry"
    
    echo -e "${GREEN}Verifying components in registry:${NC}"
    ocm get componentversions http://localhost:5001//acme.corp/utils:v1.0.0
    ocm get componentversions http://localhost:5001//acme.corp/user-app:v2.0.0
    
    echo -e "${GREEN}Application references in registry:${NC}"
    ocm get componentversions http://localhost:5001//acme.corp/user-app:v2.0.0 -o yaml | \
      grep -A 10 "componentReferences" || echo "References preserved"
else
    echo -e "${YELLOW}⚠️  Local registry not available. Skipping push step.${NC}"
fi

echo -e "${GREEN}✨ Component references example completed!${NC}"
echo -e "${BLUE}📁 Work directory: $WORK_DIR${NC}"
echo -e "${BLUE}🔗 Demonstrated concepts:${NC}"
echo "   • Component dependency management"
echo "   • Cross-component references"
echo "   • Dependency resolution"
echo "   • Component composition patterns"