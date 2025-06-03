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

### CRD Installation Problems

**Problem**: OCM CRDs not installed
```bash
Error: the server could not find the requested resource (componentversions.delivery.ocm.software)
```

**Solution**:
1. Check if cluster is running:
   ```bash
   kubectl cluster-info
   ```
2. Install OCM CRDs manually:
   ```bash
   kubectl apply -k https://github.com/open-component-model/ocm-k8s-toolkit/config/crd
   ```
3. Verify CRDs are installed:
   ```bash
   kubectl get crd | grep ocm
   ```

### Flux Installation Issues

**Problem**: Flux controllers not running
```bash
Error: flux-system namespace not found
```

**Solution**:
1. Check Flux installation:
   ```bash
   flux check
   ```
2. Install Flux manually:
   ```bash
   flux install
   ```
3. Wait for controllers to be ready:
   ```bash
   kubectl wait --for=condition=ready pod -l app=helm-controller -n flux-system --timeout=300s
   ```

### Component Deployment Fails

**Problem**: ComponentVersion not found
```bash
Error: componentversion not found in repository
```

**Solution**:
1. Verify component is in registry:
   ```bash
   ocm get components localhost:5000/demo//acme.org/hello-world:v1.0.0
   ```
2. Check if registry is accessible from cluster:
   ```bash
   kubectl run test --rm -i --tty --image=curlimages/curl -- curl http://host.docker.internal:5000/v2/_catalog
   ```
3. Update ComponentVersion resource with correct repository URL:
   ```bash
   kubectl patch componentversion hello-world -p '{"spec":{"repository":"localhost:5000/demo"}}' --type=merge
   ```

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
