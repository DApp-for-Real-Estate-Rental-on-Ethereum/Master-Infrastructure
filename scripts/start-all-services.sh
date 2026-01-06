#!/bin/bash

# Script to start the full stack (infra + blockchain + frontend + microservices)
# this script is used to test the full stack locally in my machine
# Usage: ./start-all-services.sh

set -e

PROJECT_ROOT="/home/medgm/vsc/Projet JEE"
cd "$PROJECT_ROOT"

echo "=========================================="
echo "Starting Full Stack"
echo "=========================================="

# Function to check if port is available
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1 ; then
        echo "⚠️  Port $port is already in use. Killing existing process..."
        lsof -ti:$port | xargs kill -9 2>/dev/null || true
        sleep 2
    fi
}

# Function to start a Spring Boot service
start_service() {
    local service_name=$1
    local service_dir=$2
    local port=$3
    
    echo ""
    echo "🚀 Starting $service_name on port $port..."
    check_port $port
    
    cd "$PROJECT_ROOT/$service_dir"
    nohup ./mvnw -DskipTests spring-boot:run > "/tmp/${service_name}.log" 2>&1 &
    local pid=$!
    echo "   Started with PID: $pid"
    
    # Wait a bit for the service to initialize
    sleep 3
    
    # Check if it's still running
    if ! kill -0 $pid 2>/dev/null; then
        echo "   ❌ $service_name failed to start. Check /tmp/${service_name}.log"
        return 1
    else
        echo "   ✅ $service_name is running (PID: $pid)"
        return 0
    fi
}

# Start infrastructure (PostgreSQL, RabbitMQ)
echo ""
echo "📦 Checking infrastructure (PostgreSQL, RabbitMQ)..."
if ! docker ps | grep -q "projetjee_postgres_1"; then
    echo "   Starting PostgreSQL and RabbitMQ..."
    docker compose -f infra-compose.yml up -d
    echo "   Waiting for PostgreSQL to be ready..."
    sleep 5
else
    echo "   ✅ Infrastructure is already running"
fi

# Check PostgreSQL connections
echo "   Checking PostgreSQL connection pool..."
docker exec projetjee_postgres_1 psql -U postgres -d lotfi -c "SELECT count(*) as active_connections FROM pg_stat_activity WHERE datname = 'lotfi';" 2>/dev/null || true

# Start blockchain Hardhat node
echo ""
echo "⛓️  Starting Hardhat local blockchain (port 8545)..."
check_port 8545
cd "$PROJECT_ROOT/blockchain-service"
nohup npm run node > /tmp/blockchain-node.log 2>&1 &
echo "   ✅ Hardhat node started (PID: $!) | logs: /tmp/blockchain-node.log"
sleep 2

cd "$PROJECT_ROOT"

# Start services in dependency order
echo ""
echo "🔧 Starting microservices..."

# 1. User Service (needed by others)
start_service "user-service" "user-service" 8082 || exit 1

# 2. Property Service
start_service "property-service" "property-service" 8081 || exit 1

# 3. Payment Service
start_service "payment-service" "payment-service" 8085 || exit 1

# 4. Booking Service
start_service "booking-service" "booking-service" 8083 || exit 1

# 5. Notification Service
start_service "notification-service" "notification-service" 8084 || exit 1

# 6. Reclamation Service
start_service "reclamation-service" "reclamation-service" 8091 || exit 1

# 7. API Gateway (should start last)
start_service "api-gateway" "API-Gateway" 8090 || exit 1

# 8. AI Service
echo ""
echo "🧠 Starting AI Service (Price/Risk Prediction) on port 8002..."
check_port 8002
cd "$PROJECT_ROOT/dApp-Ai-rental-price-suggestion"
nohup .venv/bin/uvicorn deployment.app:app --host 0.0.0.0 --port 8002 > /tmp/dapp-ai.log 2>&1 &
echo "   ✅ AI Service started (PID: $!) | logs: /tmp/dapp-ai.log"
sleep 2


echo ""
echo "=========================================="
echo "✅ Full stack started!"
echo "=========================================="
echo ""
echo "Service Status:"
echo "  - Infrastructure:     docker compose -f infra-compose.yml (Postgres, RabbitMQ)"
echo "  - Blockchain (L1):    Hardhat node http://127.0.0.1:8545"
echo "  - User Service:        http://localhost:8082"
echo "  - Property Service:    http://localhost:8081"
echo "  - Payment Service:     http://localhost:8085"
echo "  - Booking Service:     http://localhost:8083"
echo "  - Notification Service: http://localhost:8084"
echo "  - Reclamation Service: http://localhost:8091"
echo "  - API Gateway:         http://localhost:8090"
echo "  - AI Service:          http://localhost:8002"
echo ""
echo "Logs:"
echo "  - Blockchain: /tmp/blockchain-node.log"
echo "  - Services:   /tmp/<service-name>.log"
echo ""
echo "To stop all services, run: ./stop-all-services.sh"
echo ""

