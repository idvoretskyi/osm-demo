#!/bin/bash
# Debug script for Kubernetes context issues in CI
set -euo pipefail

echo "=== Kubernetes Context Debug Information ==="
echo "Date: $(date)"
echo "PWD: $(pwd)"
echo ""

echo "=== Environment Variables ==="
echo "KUBECONFIG: ${KUBECONFIG:-not set}"
echo "HOME: ${HOME:-not set}"
echo ""

echo "=== Kubectl Version ==="
kubectl version --client || echo "kubectl version failed"
echo ""

echo "=== Available Contexts ==="
kubectl config get-contexts || echo "No contexts available"
echo ""

echo "=== Current Context ==="
kubectl config current-context || echo "No current context set"
echo ""

echo "=== Kind Clusters ==="
kind get clusters || echo "No kind clusters found"
echo ""

echo "=== Docker Containers ==="
docker ps --filter "name=ocm-demo" || echo "No matching containers"
echo ""

echo "=== Network Connections ==="
netstat -tln | grep -E ':(6443|[0-9]{5})' || echo "No relevant ports found"
echo ""

echo "=== Cluster Info (if accessible) ==="
if kubectl cluster-info --request-timeout=5s; then
    echo "✅ Cluster is accessible"
    
    echo ""
    echo "=== Nodes ==="
    kubectl get nodes --no-headers || echo "Failed to get nodes"
    
    echo ""
    echo "=== System Pods ==="
    kubectl get pods -n kube-system --no-headers | head -10 || echo "Failed to get system pods"
else
    echo "❌ Cluster not accessible"
fi

echo ""
echo "=== File System Check ==="
echo "~/.kube exists: $(test -d ~/.kube && echo 'yes' || echo 'no')"
echo "~/.kube/config exists: $(test -f ~/.kube/config && echo 'yes' || echo 'no')"
if [[ -f ~/.kube/config ]]; then
    echo "~/.kube/config size: $(wc -c ~/.kube/config 2>/dev/null | cut -d' ' -f1) bytes"
fi

echo ""
echo "=== Debug Complete ==="
