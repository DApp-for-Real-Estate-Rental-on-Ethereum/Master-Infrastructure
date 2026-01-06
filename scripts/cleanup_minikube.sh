#!/bin/bash

echo "🧹 Cleaning up DeRent deployment..."

K8S_DIR="../k8s-minikube"

if [ ! -d "$K8S_DIR" ]; then
    echo "❌ Error: Directory $K8S_DIR not found."
    exit 1
fi

kubectl delete -f "$K8S_DIR/30-frontend.yaml" --ignore-not-found
kubectl delete -f "$K8S_DIR/20-api-gateway.yaml" --ignore-not-found
kubectl delete -f "$K8S_DIR/17-ai-service.yaml" --ignore-not-found
kubectl delete -f "$K8S_DIR/15-reclamation-service.yaml" --ignore-not-found
kubectl delete -f "$K8S_DIR/14-notification-service.yaml" --ignore-not-found
kubectl delete -f "$K8S_DIR/13-payment-service.yaml" --ignore-not-found
kubectl delete -f "$K8S_DIR/12-booking-service.yaml" --ignore-not-found
kubectl delete -f "$K8S_DIR/11-property-service.yaml" --ignore-not-found
kubectl delete -f "$K8S_DIR/10-user-service.yaml" --ignore-not-found
kubectl delete -f "$K8S_DIR/16-blockchain-service.yaml" --ignore-not-found
kubectl delete -f "$K8S_DIR/04-rabbitmq.yaml" --ignore-not-found
kubectl delete -f "$K8S_DIR/03-postgres.yaml" --ignore-not-found
kubectl delete -f "$K8S_DIR/02-configmaps.yaml" --ignore-not-found
kubectl delete -f "$K8S_DIR/01-secrets.yaml" --ignore-not-found
kubectl delete -f "$K8S_DIR/00-namespace.yaml" --ignore-not-found

echo "✅ All resources deleted."
