# Troubleshooting Guide

This guide covers common issues and solutions when working with the OCM Demo Playground.

## 🔧 Environment Setup Issues

### OCM CLI Installation Problems

**Problem**: `ocm` command not found after installation
```bash
Error: ocm: command not found
```

**Solution**:
1. Check if OCM CLI is installed correctly:
   ```bash
   which ocm
   ```
2. Add OCM CLI to your PATH:
   ```bash
   export PATH=$PATH:~/.local/bin
   echo 'export PATH=$PATH:~/.local/bin' >> ~/.bashrc
   ```
3. Re-run the environment setup:
   ```bash
   ./scripts/setup-environment.sh
   ```

### Docker Registry Issues

**Problem**: Local registry not accessible
```bash
Error: failed to access registry at localhost:5000
```

**Solution**:
1. Check if Docker registry is running:
   ```bash
   docker ps | grep registry
   ```
2. Start the registry if needed:
   ```bash
   ./scripts/ocm-utils.sh --start-registry
   ```
3. Verify registry is accessible:
   ```bash
   curl http://localhost:5000/v2/_catalog
   ```

### Kind Cluster Problems

**Problem**: Kind cluster creation fails
```bash
Error: failed to create cluster: node(s) already exist for a cluster with the name "ocm-demo"
```

**Solution**:
1. Delete existing cluster:
   ```bash
   kind delete cluster --name ocm-demo
   ```
2. Clean up any hanging resources:
   ```bash
   docker system prune -f
   ```
3. Recreate the cluster:
   ```bash
   cd examples/04-k8s-deployment
   ./setup-cluster.sh
   ```

## 🚀 Component Creation Issues

### Archive Format Problems

**Problem**: Component archive creation fails
```bash
Error: unable to create component archive
```

**Solution**:
1. Check directory permissions:
   ```bash
   ls -la /tmp/ocm-demo/
   ```
2. Create output directory if missing:
   ```bash
   mkdir -p /tmp/ocm-demo/components
   ```
3. Verify OCM workspace is clean:
   ```bash
   rm -rf .ocm/
   ocm create ca --file=component-archive.ctf
   ```

### Resource Access Issues

**Problem**: Resources not found in component
```bash
Error: resource not found in component descriptor
```

**Solution**:
1. Verify resource files exist:
   ```bash
   ls -la resources/
   ```
2. Check component descriptor syntax:
   ```bash
   ocm get components -o yaml component-archive.ctf
   ```
3. Re-add resources with correct paths:
   ```bash
   ocm add resources component-archive.ctf resources.yaml
   ```

## 🔐 Signing and Verification Issues

### Key Generation Problems

**Problem**: RSA key generation fails
```bash
Error: unable to generate RSA key pair
```

**Solution**:
1. Check OpenSSL installation:
   ```bash
   openssl version
   ```
2. Ensure output directory exists:
   ```bash
   mkdir -p /tmp/ocm-demo/keys
   ```
3. Generate keys manually:
   ```bash
   openssl genrsa -out /tmp/ocm-demo/keys/private.pem 2048
   openssl rsa -in /tmp/ocm-demo/keys/private.pem -pubout -out /tmp/ocm-demo/keys/public.pem
   ```

### Signature Verification Fails

**Problem**: Component signature verification fails
```bash
Error: signature verification failed
```

**Solution**:
1. Check if component is actually signed:
   ```bash
   ocm get components -o yaml component-archive.ctf | grep signatures
   ```
2. Verify public key format:
   ```bash
   openssl rsa -pubin -in /tmp/ocm-demo/keys/public.pem -text -noout
   ```
3. Re-sign the component:
   ```bash
   ocm sign componentversion --signature=demo-sig --private-key=/tmp/ocm-demo/keys/private.pem component-archive.ctf//acme.org/hello-world:v1.0.0
   ```

## ☸️ Kubernetes Deployment Issues

### No kubectl Context Available

**Problem**: 
```
Step 2: Checking kubectl configuration
❌ No kubectl context available
```

**Root Cause**: No Kubernetes cluster is running or kubectl is not configured properly.

**Solution**:
1. **Set up a new cluster:**
   ```bash
   cd examples/04-k8s-deployment
   ./setup-cluster.sh
   ```

2. **Check existing clusters:**
   ```bash
   kind get clusters
   kubectl config get-contexts
   ```

3. **Set the correct context:**
   ```bash
   kubectl config use-context kind-ocm-demo
   ```

### Kubernetes API Server Connection Refused

**Problem**: 
```
couldn't get current server API group list: Get "https://127.0.0.1:37667/api?timeout=32s": dial tcp 127.0.0.1:37667: connect: connection refused
```

**Root Cause**: The Kubernetes API server is not accessible at the configured address, often due to:
- Cluster not running or crashed
- Stale kubeconfig with outdated server address
- Network connectivity issues
- Kind cluster restart with new port assignment

**Solution**:

1. **Verify cluster is actually running:**
   ```bash
   kind get clusters
   docker ps | grep kindest
   ```

2. **Check cluster status and refresh kubeconfig:**
   ```bash
   # Export fresh kubeconfig from kind
   kind export kubeconfig --name=ocm-demo
   
   # Verify the API server address is correct
   kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.server}'
   ```

3. **Test API server connectivity directly:**
   ```bash
   # Get the API server URL
   API_SERVER=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.server}')
   
   # Test connectivity (should get certificate error, not connection refused)
   curl -k $API_SERVER/api/v1 --max-time 10
   ```

4. **Restart the cluster if needed:**
   ```bash
   # Clean restart of the cluster
   kind delete cluster --name ocm-demo
   cd examples/04-k8s-deployment
   ./setup-cluster.sh
   ```

5. **For CI/CD environments, ensure proper timing:**
   ```bash
   # Wait for cluster to be fully ready
   kubectl wait --for=condition=Ready nodes --all --timeout=300s
   kubectl wait --for=condition=Available --timeout=300s deployment/coredns -n kube-system
   ```

**Advanced Debugging**:
```bash
# Check if kind cluster containers are healthy
docker logs $(docker ps --filter "name=ocm-demo-control-plane" --format "{{.ID}}")

# Verify kind network connectivity
docker network ls | grep kind
docker network inspect kind

# Check for port conflicts and connectivity
lsof -i :6443  # Default k8s API port
netstat -tulpn | grep 37667  # Or the specific port from error

# Test port connectivity directly
API_SERVER=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.server}')
if [[ "$API_SERVER" =~ 127\.0\.0\.1:([0-9]+) ]]; then
    PORT="${BASH_REMATCH[1]}"
    nc -z 127.0.0.1 $PORT && echo "Port $PORT is open" || echo "Port $PORT is closed"
fi
```

**CI/CD Environment Specific Issues**:

In CI environments, the "connection refused" error often occurs due to:
- Race conditions between cluster setup and test execution
- Kind cluster port assignment changes between restarts
- Insufficient time for API server to become fully ready

To mitigate these issues in CI:
```bash
# Allow more time for cluster stabilization
sleep 10

# Use explicit kubeconfig refresh
kind export kubeconfig --name=ocm-demo

# Wait for API server to be responsive
kubectl cluster-info --request-timeout=30s

# Verify cluster readiness before proceeding
kubectl wait --for=condition=Ready nodes --all --timeout=300s
```

### Prerequisites Missing

**Problem**: 
```
❌ kind is not installed. Please install it first
```

**Solution**:

**macOS (using Homebrew):**
```bash
brew install kind
```

**macOS (manual):**
```bash
# For Intel Macs
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-darwin-amd64
# For M1/M2 Macs  
[ $(uname -m) = arm64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-darwin-arm64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

**Linux:**
```bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

### Docker Not Available

**Problem**:
```
❌ Docker is not available. Please install Docker first.
```

**Solution**:
1. **Install Docker Desktop:**
   - macOS: Download from https://www.docker.com/products/docker-desktop
   - Windows: Download from https://www.docker.com/products/docker-desktop
   - Linux: Follow instructions at https://docs.docker.com/engine/install/

2. **Start Docker:**
   - macOS/Windows: Launch Docker Desktop
   - Linux: `sudo systemctl start docker`

3. **Verify Docker is running:**
   ```bash
   docker ps
   ```

### Cluster Setup Failures

**Problem**: Cluster creation fails with various errors.

**Solution**:
1. **Clean up existing clusters:**
   ```bash
   kind delete cluster --name ocm-demo
   docker system prune -f
   ```

2. **Check Docker resources:**
   - Ensure Docker has enough memory (4GB+ recommended)
   - Ensure Docker has enough disk space (10GB+ free)

3. **Retry cluster creation:**
   ```bash
   ./setup-cluster.sh
   ```

### Nodes Not Ready

**Problem**:
```
❌ No ready nodes found
```

**Solution**:
1. **Wait for nodes to be ready:**
   ```bash
   kubectl wait --for=condition=Ready nodes --all --timeout=300s
   ```

2. **Check node status:**
   ```bash
   kubectl get nodes -o wide
   kubectl describe nodes
   ```

### OCM CRDs Not Found

**Problem**:
```
error validating data: ValidationError(ComponentVersion.spec): unknown field "component"
```

**Solution**:
1. **Install OCM CRDs:**
   ```bash
   kubectl apply -f ocm-crds.yaml
   ```

2. **Verify CRDs are installed:**
   ```bash
   kubectl get crd | grep ocm.software
   ```

### Registry Connectivity Issues

**Problem**:
```
❌ Registry failed to start within 30 seconds
```

**Solution**:
1. **Check if port is already in use:**
   ```bash
   lsof -i :5004
   ```

2. **Stop conflicting containers:**
   ```bash
   docker ps --filter "publish=5004" --format "{{.Names}}" | xargs -r docker stop
   ```

3. **Clean up and retry:**
   ```bash
   docker system prune -f
   ./deploy-example.sh
   ```

### Automatic Cluster Setup

The enhanced `deploy-example.sh` script now includes automatic cluster setup:

1. **Detects missing cluster** and attempts automatic setup
2. **Provides detailed error messages** with troubleshooting steps
3. **Includes prerequisite checks** for kind and Docker
4. **Shows troubleshooting help** when setup fails

If automatic setup fails, the script will display comprehensive troubleshooting information to help resolve the issue manually.

## 🛠️ Utility Script Issues

### Permission Denied

**Problem**: Script execution fails with permission error
```bash
Permission denied: ./run-examples.sh
```

**Solution**:
1. Make scripts executable:
   ```bash
   chmod +x examples/*/run-examples.sh
   chmod +x examples/*/*/*.sh
   chmod +x scripts/*.sh
   ```
2. Or run with bash explicitly:
   ```bash
   bash run-examples.sh
   ```

### Registry Cleanup Problems

**Problem**: Registry cleanup fails
```bash
Error: failed to remove registry container
```

**Solution**:
1. Force remove registry container:
   ```bash
   docker rm -f registry
   ```
2. Clean up registry volume:
   ```bash
   docker volume rm registry-data
   ```
3. Restart registry:
   ```bash
   ./scripts/ocm-utils.sh --start-registry
   ```

## 🌐 Network and Connectivity Issues

### Registry Connection Timeouts

**Problem**: Cannot connect to local registry from kind cluster
```bash
Error: dial tcp: lookup host.docker.internal: no such host
```

**Solution**:
1. Use kind cluster registry configuration:
   ```bash
   kubectl apply -f - <<EOF
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: local-registry-hosting
     namespace: kube-public
   data:
     localRegistryHosting.v1: |
       host: "localhost:5000"
       help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
   EOF
   ```
2. Or use cluster IP instead:
   ```bash
   kubectl get svc -n kube-system | grep registry
   ```

### Port Conflicts

**Problem**: Port 5000 already in use
```bash
Error: bind: address already in use
```

**Solution**:
1. Find what's using the port:
   ```bash
   lsof -i :5000
   ```
2. Kill the process or use a different port:
   ```bash
   docker run -d -p 5001:5000 --name registry registry:2
   ```
3. Update scripts to use the new port.

## 🐛 Debug Mode

Enable debug mode for detailed logging:

```bash
export OCM_DEBUG=true
export VERBOSE=true
./run-examples.sh
```

For OCM CLI debug output:
```bash
ocm --verbose get components component-archive.ctf
```

## 📞 Getting Help

If you encounter issues not covered here:

1. **Check OCM Documentation**: [OCM Docs](https://ocm.software/docs/)
2. **GitHub Issues**: [OCM Issues](https://github.com/open-component-model/ocm/issues)
3. **Community Support**: [OCM Community](https://github.com/open-component-model/community)
4. **Create an Issue**: Report problems in this repository

## 🔄 Quick Reset

To completely reset the demo environment:

```bash
# Stop all services
./scripts/ocm-utils.sh --cleanup

# Remove all demo artifacts
rm -rf /tmp/ocm-demo/

# Delete kind cluster
kind delete cluster --name ocm-demo

# Restart from scratch
./scripts/setup-environment.sh
```
