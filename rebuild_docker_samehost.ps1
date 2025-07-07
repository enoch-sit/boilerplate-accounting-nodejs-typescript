# Rebuild Docker Samehost Script for PowerShell
# This script stops, removes, rebuilds and starts the Docker containers using docker-compose.samehost.yml

Write-Host "🔄 Starting Docker Samehost Rebuild Process..." -ForegroundColor Cyan

# Check if .env.samehost exists
if (-not (Test-Path ".env.samehost")) {
    Write-Host "⚠️ Warning: .env.samehost file not found!" -ForegroundColor Yellow
    Write-Host "Creating .env.samehost with default values..." -ForegroundColor Yellow
    Write-Host "⚠️ IMPORTANT: Please update JWT secrets before production use!" -ForegroundColor Red
    Write-Host ""
}

# Stop and remove existing containers
Write-Host "🛑 Stopping existing containers..." -ForegroundColor Yellow
docker-compose -f docker-compose.samehost.yml down

# Remove existing images to force rebuild
Write-Host "🗑️ Removing existing images..." -ForegroundColor Yellow
docker-compose -f docker-compose.samehost.yml down --rmi all

# Remove unused volumes (optional - uncomment if you want to reset data)
# Write-Host "🗑️ Removing unused volumes..." -ForegroundColor Yellow
# docker volume prune -f

# Build and start containers
Write-Host "🏗️ Building and starting containers..." -ForegroundColor Green
docker-compose -f docker-compose.samehost.yml --env-file .env.samehost up --build -d

# Show container status
Write-Host "📋 Container status:" -ForegroundColor Blue
docker-compose -f docker-compose.samehost.yml ps

# Show logs for the auth service
Write-Host "📜 Showing auth service logs (last 20 lines):" -ForegroundColor Blue
docker-compose -f docker-compose.samehost.yml logs --tail=20 auth-service

Write-Host "✅ Docker Samehost rebuild complete!" -ForegroundColor Green
Write-Host "🌐 Auth service available at: http://localhost:3000" -ForegroundColor Cyan
Write-Host "📧 MailHog web interface: http://localhost:8025" -ForegroundColor Cyan
Write-Host "🗄️ MongoDB available at: localhost:27017" -ForegroundColor Cyan
Write-Host ""
Write-Host "� Container Names:" -ForegroundColor Blue
Write-Host "  - auth-service-dev (Main application)" -ForegroundColor Gray
Write-Host "  - auth-mongodb-samehost (Database)" -ForegroundColor Gray
Write-Host "  - auth-mailhog-samehost (Email testing)" -ForegroundColor Gray
Write-Host ""
Write-Host "�🔑 JWT Configuration:" -ForegroundColor Magenta
Write-Host "  - JWT secrets are loaded from .env.samehost" -ForegroundColor Gray
Write-Host "  - Make sure to update JWT secrets before production use" -ForegroundColor Gray
Write-Host "  - Use: openssl rand -base64 32 to generate secure secrets" -ForegroundColor Gray
Write-Host ""
Write-Host "To view logs: docker-compose -f docker-compose.samehost.yml logs -f" -ForegroundColor Gray
Write-Host "To stop: docker-compose -f docker-compose.samehost.yml down" -ForegroundColor Gray
