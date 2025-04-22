# Stop running containers
Write-Host "Stopping running containers..." -ForegroundColor Green
docker-compose -f docker-compose.dev.yml down

# Remove containers and volumes (optional, uncomment if needed)
# docker-compose -f docker-compose.dev.yml down -v

# Rebuild images without using cache
Write-Host "Rebuilding Docker images..." -ForegroundColor Green
docker-compose -f docker-compose.dev.yml build --no-cache

# Start containers
Write-Host "Starting containers..." -ForegroundColor Green
docker-compose -f docker-compose.dev.yml up -d

Write-Host "Docker rebuild complete!" -ForegroundColor Green
Write-Host "The authentication system should be available at http://localhost:3000" -ForegroundColor Cyan
Write-Host "MailHog (for email testing) is available at http://localhost:8025" -ForegroundColor Cyan
