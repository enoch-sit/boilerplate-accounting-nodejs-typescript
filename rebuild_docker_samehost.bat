@echo off
setlocal

REM Rebuild Docker Samehost Script for Windows
REM This script stops, removes, rebuilds and starts the Docker containers using docker-compose.samehost.yml

echo 🔄 Starting Docker Samehost Rebuild Process...

REM Check if .env.samehost exists
if not exist ".env.samehost" (
    echo ⚠️ Warning: .env.samehost file not found!
    echo Creating .env.samehost with default values...
    echo ⚠️ IMPORTANT: Please update JWT secrets before production use!
    echo.
)

REM Stop and remove existing containers
echo 🛑 Stopping existing containers...
docker-compose -f docker-compose.samehost.yml down

REM Remove existing images to force rebuild
echo 🗑️ Removing existing images...
docker-compose -f docker-compose.samehost.yml down --rmi all

REM Remove unused volumes (optional - uncomment if you want to reset data)
REM echo 🗑️ Removing unused volumes...
REM docker volume prune -f

REM Build and start containers
echo 🏗️ Building and starting containers...
docker-compose -f docker-compose.samehost.yml --env-file .env.samehost up --build -d

REM Show container status
echo 📋 Container status:
docker-compose -f docker-compose.samehost.yml ps

REM Show logs for the auth service
echo 📜 Showing auth service logs (last 20 lines):
docker-compose -f docker-compose.samehost.yml logs --tail=20 auth-service

echo ✅ Docker Samehost rebuild complete!
echo 🌐 Auth service available at: http://localhost:3000
echo 📧 MailHog web interface: http://localhost:8025
echo 🗄️ MongoDB available at: localhost:27017
echo.
echo � Container Names:
echo   - auth-service-dev (Main application)
echo   - auth-mongodb-samehost (Database)
echo   - auth-mailhog-samehost (Email testing)
echo.
echo �🔑 JWT Configuration:
echo   - JWT secrets are loaded from .env.samehost
echo   - Make sure to update JWT secrets before production use
echo   - Use: openssl rand -base64 32 to generate secure secrets
echo.
echo To view logs: docker-compose -f docker-compose.samehost.yml logs -f
echo To stop: docker-compose -f docker-compose.samehost.yml down
