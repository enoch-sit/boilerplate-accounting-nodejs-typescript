#!/bin/bash

# Rebuild Docker Samehost Script
# This script stops, removes, rebuilds and starts the Docker containers using docker-compose.samehost.yml

echo "🔄 Starting Docker Samehost Rebuild Process..."

# Check if .env.samehost exists
if [ ! -f ".env.samehost" ]; then
    echo "⚠️ Warning: .env.samehost file not found!"
    echo "Creating .env.samehost with default values..."
    echo "⚠️ IMPORTANT: Please update JWT secrets before production use!"
    echo ""
fi

# Stop and remove existing containers
echo "🛑 Stopping existing containers..."
docker-compose -f docker-compose.samehost.yml down

# Remove existing images to force rebuild
echo "🗑️ Removing existing images..."
docker-compose -f docker-compose.samehost.yml down --rmi all

# Remove unused volumes (optional - uncomment if you want to reset data)
# echo "🗑️ Removing unused volumes..."
# docker volume prune -f

# Build and start containers
echo "🏗️ Building and starting containers..."
docker-compose -f docker-compose.samehost.yml --env-file .env.samehost up --build -d

# Show container status
echo "📋 Container status:"
docker-compose -f docker-compose.samehost.yml ps

# Show logs for the auth service
echo "📜 Showing auth service logs (last 20 lines):"
docker-compose -f docker-compose.samehost.yml logs --tail=20 auth-service

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
echo "To view logs: docker-compose -f docker-compose.samehost.yml logs -f"
echo "To stop: docker-compose -f docker-compose.samehost.yml down"
