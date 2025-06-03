#!/bin/bash
set -e

echo "Deploying MyApp v1.0.0..."
kubectl apply -f ../config/app.yaml

echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=myapp --timeout=300s

echo "Deployment completed successfully!"
