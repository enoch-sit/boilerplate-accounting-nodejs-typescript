#!/bin/bash

# Rebuild Docker Samehost Script - Linux Version
# This script stops, removes, rebuilds and starts the Docker containers using docker-compose.samehost.yml

echo "🔄 Starting Docker Samehost Rebuild Process..."

# Check if user has docker permissions
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker permission denied!"
    echo "📋 To fix this, run the following commands:"
    echo "   sudo usermod -aG docker \$USER"
    echo "   newgrp docker"
    echo "   # Or log out and log back in"
    echo ""
    echo "⚠️ After fixing permissions, run this script again."
    exit 1
fi

# Check if .env.samehost exists
if [ ! -f ".env.samehost" ]; then
    echo "⚠️ Warning: .env.samehost file not found!"
    echo "📋 Creating .env.samehost with default values..."
    echo "⚠️ IMPORTANT: Please update JWT secrets before production use!"
    
    # Create default .env.samehost file
    cat > .env.samehost << 'EOF'
# Environment Configuration for Samehost Development
NODE_ENV=samehost

# JWT Configuration
JWT_ACCESS_SECRET=your-super-secret-jwt-access-key-change-this-in-production
JWT_REFRESH_SECRET=your-super-secret-jwt-refresh-key-change-this-in-production
JWT_ACCESS_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d

# Database Configuration
MONGODB_URI=mongodb://mongodb:27017/auth_db

# Email Configuration
EMAIL_HOST=mailhog
EMAIL_PORT=1025
EMAIL_USER=
EMAIL_PASS=
EMAIL_FROM=noreply@example.com

# Application Configuration
HOST_URL=http://localhost:3000
CORS_ORIGIN=http://localhost:3000
PORT=3000
LOG_LEVEL=debug

# Security Configuration
PASSWORD_RESET_EXPIRES_IN=1h
VERIFICATION_CODE_EXPIRES_IN=24h
EOF
    
    echo "✅ Created .env.samehost with default values"
    echo "🔐 Please update JWT secrets before production use!"
    echo ""
fi

# Load environment variables
set -a
source .env.samehost
set +a

echo "🔍 Checking environment variables..."
if [ -z "$JWT_ACCESS_SECRET" ] || [ "$JWT_ACCESS_SECRET" = "your-super-secret-jwt-access-key-change-this-in-production" ]; then
    echo "⚠️ Warning: Default JWT secrets detected. Please update them for security!"
fi

# Stop and remove existing containers
echo "🛑 Stopping existing containers..."
docker compose -f docker-compose.samehost.yml down

# Remove existing images to force rebuild
echo "🗑️ Removing existing images..."
docker compose -f docker-compose.samehost.yml down --rmi all

# Remove unused volumes (optional - uncomment if you want to reset data)
# echo "🗑️ Removing unused volumes..."
# docker volume prune -f

# Build and start containers
echo "🏗️ Building and starting containers..."
docker compose -f docker-compose.samehost.yml --env-file .env.samehost up --build -d

# Wait a moment for containers to start
echo "⏳ Waiting for containers to start..."
sleep 5

# Show container status
echo "📋 Container status:"
docker compose -f docker-compose.samehost.yml ps

# Show logs for the auth service
echo "📜 Showing auth service logs (last 20 lines):"
docker compose -f docker-compose.samehost.yml logs --tail=20 auth-service

echo ""
echo "✅ Docker Samehost rebuild complete!"
echo "🌐 Auth service available at: http://localhost:3000"
echo "📧 MailHog web interface: http://localhost:8025"
echo "🗄️ MongoDB available at: localhost:27017"
echo ""
echo "🔧 Container Names:"
echo "  - auth-service-dev (Main application)"
echo "  - auth-mongodb-samehost (Database)"
echo "  - auth-mailhog-samehost (Email testing)"
echo ""
echo "📋 Useful commands:"
echo "  View logs: docker compose -f docker-compose.samehost.yml logs -f"
echo "  Stop: docker compose -f docker-compose.samehost.yml down"
echo "  Check network: ./check_network.sh"
echo "  Create users: cd quickCreateAdminPySamehost && python3 create_users.py"
