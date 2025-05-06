@echo off
echo Starting Docker containers for Simple Accounting...
color 0A

echo Checking if containers are already running...
docker ps | findstr "auth-service"
if %ERRORLEVEL% EQU 0 (
    echo Docker containers are already running.
    echo The authentication system should be available at http://localhost:3000
    echo MailHog (for email testing) is available at http://localhost:8025
    pause
    exit /b
)

echo Starting containers...
docker-compose -f docker-compose.dev.yml up -d

echo Docker startup complete!
echo The authentication system should be available at http://localhost:3000
echo MailHog (for email testing) is available at http://localhost:8025
pause