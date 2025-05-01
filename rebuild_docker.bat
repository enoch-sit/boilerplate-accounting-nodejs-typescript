@echo off
echo Stopping running containers...
color 0A
docker-compose -f docker-compose.dev.yml down

rem Remove containers and volumes (optional, uncomment if needed)
rem docker-compose -f docker-compose.dev.yml down -v

echo Rebuilding Docker images...
docker-compose -f docker-compose.dev.yml build --no-cache

echo Starting containers...
docker-compose -f docker-compose.dev.yml up -d

echo Docker rebuild complete!
echo The authentication system should be available at http://localhost:3000
echo MailHog (for email testing) is available at http://localhost:8025
pause