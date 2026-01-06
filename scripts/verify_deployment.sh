#!/bin/bash

echo "🔍 Verifying DeRent Deployment Status..."

echo "---------------------------------------------------"
echo "PODS STATUS:"
kubectl get pods -n derent
echo "---------------------------------------------------"

echo "SERVICES STATUS:"
kubectl get svc -n derent
echo "---------------------------------------------------"

echo "API GATEWAY URL:"
minikube service api-gateway -n derent --url
echo "---------------------------------------------------"

echo "FRONTEND URL:"
minikube service frontend -n derent --url
echo "---------------------------------------------------"
