#!/bin/bash

# Script to stop the full stack (infra + blockchain + frontend + microservices)
# used only for local testing
# Usage: ./stop-all-services.sh

set -e

echo "=========================================="
echo "Stopping Full Stack"
echo "=========================================="

# Define services and their ports
declare -A services
services=(
    ["user-service"]="8082"
    ["property-service"]="8081"
    ["payment-service"]="8085"
    ["booking-service"]="8083"
    ["notification-service"]="8084"
    ["reclamation-service"]="8091"
    ["api-gateway"]="8090"
    ["ai-service"]="8002"
    ["hardhat-node"]="8545"
)

# Stop all services
echo "🛑 Stopping microservices and blockchain node..."
for service_name in "${!services[@]}"; do
    port=${services[$service_name]}
    pid=$(lsof -ti:$port 2>/dev/null || true)
    if [ -n "$pid" ]; then
        echo "   - Stopping $service_name (PID: $pid) on port $port"
        kill -9 $pid 2>/dev/null || true
    else
        echo "   - $service_name is not running on port $port"
    fi
done

# An additional pkill for any stray Spring Boot processes, just in case
pkill -f "spring-boot:run" 2>/dev/null || true

# Stop infrastructure (PostgreSQL, RabbitMQ)
echo "🛑 Stopping infrastructure (PostgreSQL, RabbitMQ)..."
docker compose -f infra-compose.yml down 2>/dev/null || echo "   - Infrastructure is not running or already stopped"

sleep 2

echo ""
echo "✅ Full stack stopped!"
echo ""

