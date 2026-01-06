#!/bin/bash

# DeRent Decentralized Deployment Script for Minikube
# Usage: ./deploy_minikube.sh

set -e # Exit on error

echo "🚀 Starting DeRent Minikube Deployment..."

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 1. Prerequisites Check
if ! command_exists kubectl; then
    echo "❌ kubectl is not installed."
    exit 1
fi

if ! command_exists minikube; then
    echo "⚠️ minikube not found. Assuming you are using an alternative k8s cluster."
else
    status=$(minikube status --format='{{.Host}}')
    if [[ "$status" != "Running" ]]; then
        echo "⚠️ Minikube is not running. Please start it with 'minikube start'."
        exit 1
    fi
fi

echo "✅ Environment check passed."

# Navigate to K8s directory
K8S_DIR="../k8s-minikube"
if [ ! -d "$K8S_DIR" ]; then
    echo "❌ Error: Directory $K8S_DIR not found. Please run this script from 'Master/scripts'."
    exit 1
fi

# 2. Namespace & Configuration
echo "📦 Applying Namespaces and Configurations..."
kubectl apply -f "$K8S_DIR/00-namespace.yaml"
kubectl apply -f "$K8S_DIR/01-secrets.yaml"
kubectl apply -f "$K8S_DIR/02-configmaps.yaml"

# 3. Infrastructure (DB + Queue + Blockchain)
echo "🏗️  Deploying Infrastructure..."
kubectl apply -f "$K8S_DIR/03-postgres.yaml"
kubectl apply -f "$K8S_DIR/04-rabbitmq.yaml"
kubectl apply -f "$K8S_DIR/16-blockchain-service.yaml"

echo "⏳ Waiting 30s for infrastructure to stabilize..."
sleep 30

# 4. Backend Microservices
echo "⚙️  Deploying Backend Services..."
kubectl apply -f "$K8S_DIR/10-user-service.yaml"
kubectl apply -f "$K8S_DIR/11-property-service.yaml"
kubectl apply -f "$K8S_DIR/12-booking-service.yaml"
kubectl apply -f "$K8S_DIR/13-payment-service.yaml"
kubectl apply -f "$K8S_DIR/14-notification-service.yaml"
kubectl apply -f "$K8S_DIR/15-reclamation-service.yaml"

# 5. AI Service
echo "🧠 Deploying AI Service..."
kubectl apply -f "$K8S_DIR/17-ai-service.yaml"

# 6. API Gateway & Frontend
echo "🌐 Deploying API Gateway & Frontend..."
kubectl apply -f "$K8S_DIR/20-api-gateway.yaml"
kubectl apply -f "$K8S_DIR/30-frontend.yaml"

echo "✅ Deployment commands issued successfully!"
echo "👉 Run './verify_deployment.sh' to check pod status."
