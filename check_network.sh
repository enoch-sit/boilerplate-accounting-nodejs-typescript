#!/bin/bash

echo "Checking Docker network configuration..."
echo ""

echo "=== Docker Network Info ==="
docker network ls | grep auth-network
echo ""

echo "=== Service IP Addresses ==="
if docker inspect auth-service-dev >/dev/null 2>&1; then
    IP=$(docker inspect auth-service-dev --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
    echo "auth-service-dev: $IP"
fi

if docker inspect auth-mongodb-samehost >/dev/null 2>&1; then
    IP=$(docker inspect auth-mongodb-samehost --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
    echo "auth-mongodb-samehost: $IP"
fi

if docker inspect auth-mailhog-samehost >/dev/null 2>&1; then
    IP=$(docker inspect auth-mailhog-samehost --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
    echo "auth-mailhog-samehost: $IP"
fi
echo ""

echo "=== Network Details ==="
docker network inspect auth-network 2>/dev/null | grep -E '"Subnet"|"Gateway"|"IPAddress"' | head -10
echo ""

echo "=== Test DNS Resolution ==="
if docker exec auth-service-dev nslookup mongodb >/dev/null 2>&1; then
    echo "✅ DNS resolution working: mongodb resolves successfully"
else
    echo "❌ DNS resolution test failed or container not running"
fi
echo ""

echo "=== Container Status ==="
echo "Running containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "auth-|NAMES"
echo ""

echo "=== Network Connectivity Test ==="
if docker exec auth-service-dev ping -c 1 mongodb >/dev/null 2>&1; then
    echo "✅ Network connectivity: auth-service-dev can reach mongodb"
else
    echo "❌ Network connectivity test failed"
fi

if docker exec auth-service-dev ping -c 1 mailhog >/dev/null 2>&1; then
    echo "✅ Network connectivity: auth-service-dev can reach mailhog"
else
    echo "❌ Network connectivity test failed"
fi
echo ""

echo "=== Port Accessibility ==="
echo "Testing external port access..."
if command -v curl >/dev/null 2>&1; then
    if curl -s http://localhost:3000/health >/dev/null 2>&1; then
        echo "✅ API accessible at http://localhost:3000"
    else
        echo "❌ API not accessible at http://localhost:3000"
    fi
    
    if curl -s http://localhost:8025 >/dev/null 2>&1; then
        echo "✅ MailHog UI accessible at http://localhost:8025"
    else
        echo "❌ MailHog UI not accessible at http://localhost:8025"
    fi
else
    echo "ℹ️  curl not available for port testing"
fi
echo ""

echo "Network check completed!"
