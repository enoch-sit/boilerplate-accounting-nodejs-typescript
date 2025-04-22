#!/bin/bash

# Stop running containers
echo "Stopping running containers..."
docker-compose -f docker-compose.dev.yml down

# Remove containers and volumes (optional, uncomment if needed)
# docker-compose -f docker-compose.dev.yml down -v

# Rebuild images without using cache
echo "Rebuilding Docker images..."
docker-compose -f docker-compose.dev.yml build --no-cache

# Start containers
echo "Starting containers..."
docker-compose -f docker-compose.dev.yml up -d

echo "Docker rebuild complete!"
echo "The authentication system should be available at http://localhost:3000"
echo "MailHog (for email testing) is available at http://localhost:8025"
