@echo off
echo Checking Docker network configuration...
echo.

echo === Docker Network Info ===
docker network ls | findstr auth-network
echo.

echo === Service IP Addresses ===
for /f "tokens=*" %%i in ('docker inspect auth-service-dev --format="{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" 2^>nul') do echo auth-service-dev: %%i
for /f "tokens=*" %%i in ('docker inspect auth-mongodb-samehost --format="{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" 2^>nul') do echo auth-mongodb-samehost: %%i
for /f "tokens=*" %%i in ('docker inspect auth-mailhog-samehost --format="{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" 2^>nul') do echo auth-mailhog-samehost: %%i
echo.

echo === Network Details ===
docker network inspect auth-network 2>nul | findstr "Subnet Gateway IPAddress"
echo.

echo === Container Status ===
echo Running containers:
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | findstr "auth- NAMES"
echo.

echo === Test DNS Resolution ===
docker exec auth-service-dev nslookup mongodb >nul 2>&1 && echo ✅ DNS resolution working: mongodb resolves successfully || echo ❌ DNS resolution test failed or container not running
echo.

echo === Network Connectivity Test ===
docker exec auth-service-dev ping -n 1 mongodb >nul 2>&1 && echo ✅ Network connectivity: auth-service-dev can reach mongodb || echo ❌ Network connectivity test failed
docker exec auth-service-dev ping -n 1 mailhog >nul 2>&1 && echo ✅ Network connectivity: auth-service-dev can reach mailhog || echo ❌ Network connectivity test failed
echo.

echo === Port Accessibility ===
echo Testing external port access...
curl -s http://localhost:3000/health >nul 2>&1 && echo ✅ API accessible at http://localhost:3000 || echo ❌ API not accessible at http://localhost:3000
curl -s http://localhost:8025 >nul 2>&1 && echo ✅ MailHog UI accessible at http://localhost:8025 || echo ❌ MailHog UI not accessible at http://localhost:8025
echo.

echo Network check completed!
pause
