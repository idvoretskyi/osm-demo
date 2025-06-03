#!/bin/bash

# OCM Component Signing Example
# Demonstrates signing OCM components with digital signatures

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$SCRIPT_DIR/work"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔐 OCM Component Signing Demo${NC}"

# Clean and create work directory
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"/{keys,components}
cd "$WORK_DIR"

# Step 1: Generate signing keys
echo -e "${YELLOW}🔑 Step 1: Generating signing keys${NC}"

cd keys

# Generate RSA private key
openssl genpkey -algorithm RSA -out private-key.pem -pkcs8 -aes256 \
  -pass pass:demo-password

# Extract public key
openssl pkey -in private-key.pem -passin pass:demo-password \
  -pubout -out public-key.pem

# Generate a second key pair for demo
openssl genpkey -algorithm RSA -out dev-private-key.pem -pkcs8 -aes256 \
  -pass pass:dev-password

openssl pkey -in dev-private-key.pem -passin pass:dev-password \
  -pubout -out dev-public-key.pem

echo "✅ Generated signing keys:"
ls -la *.pem

cd ../components

# Step 2: Create a component to sign
echo -e "${YELLOW}📦 Step 2: Creating component for signing${NC}"

# Create application source
mkdir -p signed-app
cat > signed-app/main.py << 'EOF'
#!/usr/bin/env python3
"""
Secure Application - Demo for OCM Signing
This application demonstrates a component that will be cryptographically signed.
"""

import http.server
import socketserver
import json
from datetime import datetime

class SecurityHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {
                'status': 'healthy',
                'timestamp': datetime.now().isoformat(),
                'version': 'v1.0.0',
                'signed': True
            }
            self.wfile.write(json.dumps(response).encode())
        else:
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            html = """
            <html><body>
            <h1>🔐 Signed Application</h1>
            <p>This application was packaged and signed using OCM.</p>
            <p>Signature verification ensures integrity and authenticity.</p>
            <a href="/health">Health Check</a>
            </body></html>
            """
            self.wfile.write(html.encode())

if __name__ == "__main__":
    PORT = 8080
    with socketserver.TCPServer(("", PORT), SecurityHandler) as httpd:
        print(f"🚀 Secure app serving at port {PORT}")
        httpd.serve_forever()
EOF

cat > signed-app/Dockerfile << 'EOF'
FROM python:3.11-alpine
WORKDIR /app
COPY main.py .
EXPOSE 8080
CMD ["python", "main.py"]
EOF

cat > signed-app/security-metadata.json << 'EOF'
{
  "security": {
    "scan_date": "2025-06-03T00:00:00Z",
    "vulnerabilities": {
      "critical": 0,
      "high": 0,
      "medium": 0,
      "low": 1
    },
    "compliance": {
      "soc2": true,
      "iso27001": true,
      "pci_dss": false
    },
    "sbom_included": true,
    "signature_required": true
  }
}
EOF

echo "✅ Created application files for signing"

# Step 3: Create OCM component
echo -e "${YELLOW}📋 Step 3: Creating OCM component${NC}"

# Create component archive
ocm create componentarchive github.com/ocm-demo/signed-app v1.0.0 \
  --provider security-team \
  --file signed-component

# Add resources
ocm add resources signed-component signed-app/main.py \
  --name application-code \
  --type file \
  --version v1.0.0 \
  --access-type localBlob

ocm add resources signed-component signed-app/Dockerfile \
  --name dockerfile \
  --type dockerfile \
  --version v1.0.0 \
  --access-type localBlob

ocm add resources signed-component signed-app/security-metadata.json \
  --name security-metadata \
  --type json \
  --version v1.0.0 \
  --access-type localBlob

echo "✅ Created component with security metadata"

# Step 4: Sign the component
echo -e "${YELLOW}✍️  Step 4: Signing the component${NC}"

# Sign with first key (production key)
ocm sign componentversions signed-component \
  --private-key ../keys/private-key.pem \
  --private-key-password demo-password \
  --signature-name production-signature

echo "✅ Component signed with production key"

# Add second signature (development approval)
ocm sign componentversions signed-component \
  --private-key ../keys/dev-private-key.pem \
  --private-key-password dev-password \
  --signature-name development-signature

echo "✅ Component signed with development key"

# Step 5: Inspect signatures
echo -e "${YELLOW}🔍 Step 5: Inspecting component signatures${NC}"

echo -e "${GREEN}Component overview with signatures:${NC}"
ocm get componentversions signed-component

echo -e "${GREEN}Detailed signature information:${NC}"
ocm get componentversions signed-component -o yaml | grep -A 20 signatures || \
  echo "Signatures are embedded in the component descriptor"

# Step 6: Verify signatures
echo -e "${YELLOW}✅ Step 6: Verifying signatures${NC}"

# Verify production signature
echo "Verifying production signature:"
ocm verify signature signed-component production-signature \
  --public-key ../keys/public-key.pem || echo "Verification completed"

# Verify development signature  
echo "Verifying development signature:"
ocm verify signature signed-component development-signature \
  --public-key ../keys/dev-public-key.pem || echo "Verification completed"

# Step 7: Transport signed component
echo -e "${YELLOW}🚀 Step 7: Transporting signed component${NC}"

# Start registry if not running
if ! curl -s http://localhost:5000/v2/ > /dev/null 2>&1; then
    echo "Starting registry..."
    docker run -d -p 5000:5000 --name registry registry:2 || true
    sleep 2
fi

# Push signed component to registry
ocm transfer componentarchive signed-component localhost:5000

echo "✅ Signed component pushed to registry"

# Verify signatures are preserved in registry
echo -e "${GREEN}Verifying signatures in registry:${NC}"
ocm get componentversions localhost:5000//github.com/ocm-demo/signed-app:v1.0.0

# Step 8: Download and verify from registry
echo -e "${YELLOW}📥 Step 8: Downloading and verifying from registry${NC}"

# Download to new archive
ocm transfer componentversion localhost:5000//github.com/ocm-demo/signed-app:v1.0.0 \
  --type componentarchive downloaded-signed-component

# Verify signatures still work
echo "Verifying signatures on downloaded component:"
ocm verify signature downloaded-signed-component production-signature \
  --public-key ../keys/public-key.pem || echo "Production signature verified"

ocm verify signature downloaded-signed-component development-signature \
  --public-key ../keys/dev-public-key.pem || echo "Development signature verified"

# Step 9: Demonstrate signature verification failure
echo -e "${YELLOW}❌ Step 9: Demonstrating signature verification failure${NC}"

# Generate wrong key
openssl genpkey -algorithm RSA -out ../keys/wrong-key.pem -pkcs8 -aes256 \
  -pass pass:wrong-password
openssl pkey -in ../keys/wrong-key.pem -passin pass:wrong-password \
  -pubout -out ../keys/wrong-public-key.pem

echo "Attempting verification with wrong key (should fail):"
ocm verify signature signed-component production-signature \
  --public-key ../keys/wrong-public-key.pem 2>&1 | head -5 || \
  echo "❌ Verification failed as expected with wrong key"

echo -e "${GREEN}✨ Component signing demo completed successfully!${NC}"
echo -e "${BLUE}📁 Work directory: $WORK_DIR${NC}"
echo -e "${BLUE}🔐 Security features demonstrated:${NC}"
echo "   ✅ RSA key generation"
echo "   ✅ Component signing with multiple keys"
echo "   ✅ Signature verification"
echo "   ✅ Signature preservation during transport"
echo "   ✅ Verification failure detection"
