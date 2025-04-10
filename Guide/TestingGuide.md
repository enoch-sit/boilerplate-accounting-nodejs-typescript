# Comprehensive Testing Guide

This guide provides detailed instructions for testing the TypeScript Authentication System in different environments, with a special focus on Windows Docker-based development and testing.

## Table of Contents

1. [Development Testing in Docker](#development-testing-in-docker)
2. [Manual Testing with MailHog](#manual-testing-with-mailhog)
3. [Automated Testing](#automated-testing)
4. [Production Deployment Testing](#production-deployment-testing)
5. [Real Email Verification Testing](#real-email-verification-testing)
6. [Testing Admin User Creation API](#testing-admin-user-creation-api)
7. [Architecture Compatibility Issues](#architecture-compatibility-issues)
8. [Troubleshooting Common Issues](#troubleshooting-common-issues)

## Development Testing in Docker

### Setup Docker Environment

1. **Start the Development Environment**:
   ```powershell
   # Start the whole stack (auth service, MongoDB, and MailHog)
   docker-compose -f docker-compose.dev.yml up
   
   # Or to run in detached mode
   docker-compose -f docker-compose.dev.yml up -d
   ```

2. **Verify Services are Running**:
   ```powershell
   # Check all containers
   docker ps
   
   # Expected output should show auth-service-dev, auth-mongodb, and auth-mailhog
   ```

3. **Access Service Endpoints**:
   - API Endpoint: http://localhost:3000/api
   - MailHog UI: http://localhost:8025

### Network Configuration for Windows

When testing on Windows with Docker Desktop:

1. **Container-to-Container Communication**:
   - Services inside Docker can access each other using their service names (e.g., `mongodb`, `auth-service`, `mailhog`)

2. **Host-to-Container Communication**:
   - From your Windows machine, access services using `localhost` and the mapped port
   - Example: `http://localhost:3000/api/auth/signup`

3. **Container-to-Host Communication**:
   - If your tests need to access a service running on your host:
   - Use `host.docker.internal` instead of `localhost`
   - Example: Set `API_URL=http://host.docker.internal:3000/api` in your tests

## Manual Testing with MailHog

MailHog provides a web interface to inspect emails sent by the application during testing.

### Using MailHog UI

1. **Access MailHog Web Interface**:
   - Open http://localhost:8025 in your browser

2. **Register a New User**:
   - Send a POST request to `/api/auth/signup` with valid credentials
   - Example:
     ```json
     {
       "username": "testuser",
       "email": "test@example.com",
       "password": "Password123!"
     }
     ```

3. **Find Verification Email**:
   - Check MailHog UI for the verification email
   - Extract the verification code/token from the email
   - Verify using `/api/auth/verify-email` endpoint

4. **Test Password Reset Flow**:
   - Send a request to `/api/auth/forgot-password`
   - Find the reset email in MailHog UI
   - Extract the reset token
   - Complete the reset using `/api/auth/reset-password`

### Tools for API Testing

1. **Insomnia or Postman**:
   - Create a collection for your API endpoints
   - Set up environment variables for tokens
   - Use collection runners for basic flow testing

2. **PowerShell or cURL**:
   - For ad-hoc testing and scripting
   - Example:
     ```powershell
     Invoke-RestMethod -Uri 'http://localhost:3000/api/auth/signup' -Method Post -ContentType 'application/json' -Body '{"username":"testuser","email":"test@example.com","password":"Password123!"}'
     ```

## Automated Testing

### Running Jest Tests

1. **Run All Tests in Docker**:
   ```powershell
   # Run tests in the auth-test service
   docker-compose -f docker-compose.dev.yml run --rm auth-test
   
   # Run tests with specific options
   docker-compose -f docker-compose.dev.yml run --rm auth-test npm test -- --verbose
   ```

2. **Run Specific Tests**:
   ```powershell
   docker-compose -f docker-compose.dev.yml run --rm auth-test npm test -- -t "Role-Based Access Control Tests"
   ```

3. **Update Test Configuration**:
   - The test service connects to a separate test database (`auth_test_db`) to avoid affecting development data
   - MailHog is used for email testing
   - Edit environment variables in the `auth-test` service in `docker-compose.dev.yml` to modify test behavior

### Using the Test Pipeline

For comprehensive testing, use the built-in test pipeline:

1. **Run Complete Test Pipeline**:
   ```powershell
   # Make sure you have PowerShell execution policy set correctly
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   
   # Run the test pipeline
   .\tests\test-pipeline.ps1
   ```

2. **Run Specific Test Segments**:
   ```powershell
   # Run only unit tests
   .\tests\test-pipeline.ps1 -UnitTestsOnly
   
   # Run only API tests
   .\tests\test-pipeline.ps1 -ApiTestsOnly
   ```

### Automated Email Verification Tests

1. **Using Direct Database Access**:
   - When `BYPASS_MAILHOG=true`, tests fetch verification tokens directly from the database
   - This allows for faster testing without needing email verification

2. **Using Auto-Verify Test Script**:
   ```powershell
   # Run automated verification tests
   .\tests\auto-verify-tests.ps1
   ```

## Production Deployment Testing

### Setting Up Production Test Environment

1. **Create .env.production File**:
   ```dotenv
   NODE_ENV=production
   MONGO_URI=mongodb://username:password@mongodb:27017/auth_db
   JWT_ACCESS_SECRET=your_secure_access_secret
   JWT_REFRESH_SECRET=your_secure_refresh_secret
   JWT_ACCESS_EXPIRES_IN=15m
   JWT_REFRESH_EXPIRES_IN=7d
   EMAIL_HOST=your_smtp_server
   EMAIL_PORT=587
   EMAIL_USER=your_email_user
   EMAIL_PASS=your_email_password
   EMAIL_FROM=noreply@your-domain.com
   PASSWORD_RESET_EXPIRES_IN=1h
   VERIFICATION_CODE_EXPIRES_IN=15m
   FRONTEND_URL=https://your-domain.com
   CORS_ORIGIN=https://your-domain.com
   PORT=3000
   LOG_LEVEL=info
   ```

2. **Create Environment Variables File for Docker**:
   ```bash
   # Create .env file for docker-compose.prod.yml
   echo "JWT_ACCESS_SECRET=your_secure_access_secret" > .env
   echo "JWT_REFRESH_SECRET=your_secure_refresh_secret" >> .env
   echo "EMAIL_HOST=your_smtp_server" >> .env
   # Add all other required environment variables
   ```

3. **Start Production Environment**:
   ```bash
   docker-compose -f docker-compose.prod.yml up -d
   ```

### Testing Production Deployment

1. **Health Check**:
   ```bash
   curl http://localhost:3000/health
   ```

2. **Smoke Tests**:
   ```bash
   # Create a user
   curl -X POST http://localhost:3000/api/auth/signup \
     -H "Content-Type: application/json" \
     -d '{"username":"prod_test","email":"prod_test@example.com","password":"ProdTest123!"}'
   
   # Additional smoke tests for core features
   ```

3. **Running Python Integration Test** (see Python test script section)

## Real Email Verification Testing

For testing with real email verification:

1. **Configure Email Settings**:
   - Update `.env.development` or `.env.production` with actual SMTP settings
   - For testing, you can use services like Gmail, Mailtrap, or AWS SES

2. **Run Manual Tests with Real Email**:
   - Register a user with your real email address
   - Check your inbox for the verification email
   - Complete the verification process
   - This validates the complete end-to-end flow

3. **Use the Python Test Script for Real-World Testing**:
   - The script allows entering verification codes from actual emails
   - Run the script and follow the prompts (see Python test script section)

## Testing Admin User Creation API

The system includes a new endpoint for administrators to create users with specific roles. This section explains how to test this functionality in different environments.

### Manual Testing with Admin User Creation

1. **Authenticate as an Admin**:
   ```powershell
   # Login with an admin account
   $adminLoginResponse = Invoke-RestMethod -Uri 'http://localhost:3000/api/auth/login' -Method Post -ContentType 'application/json' -Body '{"username":"admin","password":"AdminPassword123!"}'
   
   # Extract the access token
   $adminToken = $adminLoginResponse.accessToken
   ```

2. **Create a Regular User as Admin**:
   ```powershell
   # Create a new regular user
   $createUserResponse = Invoke-RestMethod -Uri 'http://localhost:3000/api/admin/users' -Method Post -Headers @{
       "Authorization" = "Bearer $adminToken"
   } -ContentType 'application/json' -Body '{
       "username": "newuser1", 
       "email": "newuser1@example.com", 
       "password": "Password123!", 
       "role": "user",
       "skipVerification": true
   }'
   
   # Check the response
   $createUserResponse
   ```

3. **Create a Supervisor User as Admin**:
   ```powershell
   # Create a new supervisor user
   $createSupervisorResponse = Invoke-RestMethod -Uri 'http://localhost:3000/api/admin/users' -Method Post -Headers @{
       "Authorization" = "Bearer $adminToken"
   } -ContentType 'application/json' -Body '{
       "username": "newsupervisor", 
       "email": "supervisor@example.com", 
       "password": "Password123!", 
       "role": "supervisor",
       "skipVerification": true
   }'
   
   # Check the response
   $createSupervisorResponse
   ```

4. **Verify Created Users**:
   ```powershell
   # List all users
   $usersResponse = Invoke-RestMethod -Uri 'http://localhost:3000/api/admin/users' -Method Get -Headers @{
       "Authorization" = "Bearer $adminToken"
   }
   
   # Check the users list
   $usersResponse.users | Format-Table -Property username, email, role, isVerified
   ```

### Testing with curl (Bash/Git Bash)

```bash
# 1. Login as admin
admin_response=$(curl -s -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"AdminPassword123!"}')
  
# Extract token
admin_token=$(echo $admin_response | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4)

# 2. Create a new user
curl -X POST http://localhost:3000/api/admin/users \
  -H "Authorization: Bearer $admin_token" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "newuser2",
    "email": "newuser2@example.com",
    "password": "Password123!",
    "role": "user",
    "skipVerification": true
  }'

# 3. Create a supervisor user
curl -X POST http://localhost:3000/api/admin/users \
  -H "Authorization: Bearer $admin_token" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "newsupervisor2",
    "email": "supervisor2@example.com",
    "password": "Password123!",
    "role": "supervisor",
    "skipVerification": true
  }'

# 4. List all users
curl -X GET http://localhost:3000/api/admin/users \
  -H "Authorization: Bearer $admin_token"
```

### Testing in Docker Environment

When testing in a Docker environment, make sure to use the correct service name:

```bash
# Using the deploy_test.py script with admin creation testing
python tests/deploy_test.py --url http://auth-service:3000 --admin-test true
```

### Common Issues and Troubleshooting

1. **Unauthorized Error (401)**:
   - Ensure you're using a valid admin token
   - Check if the token has expired (tokens expire after 15 minutes by default)
   - Verify you're including the token in the Authorization header

2. **Forbidden Error (403)**:
   - Verify that the authenticated user has the admin role
   - Regular users and supervisors cannot access this endpoint
   - Admin users cannot create other admin users (by design)

3. **Bad Request Error (400)**:
   - Check that all required fields (username, email, password) are provided
   - Ensure the email format is valid
   - Verify that the role is valid (only "user" or "supervisor" are allowed)

4. **Email Already Exists Error**:
   - If you receive an error that the email already exists, try using a different email address
   - The system prevents duplicate emails to maintain data integrity

By following these testing steps, you can verify that the admin user creation API works correctly in different environments.

## Architecture Compatibility Issues

When running the authentication system in Docker containers across different architectures (like x86 vs ARM), you may encounter compatibility issues with native modules.

### Native Module Issues

1. **Symptoms of Native Module Problems**:
   - Connection errors when trying to access API endpoints
   - Errors in logs containing messages like "Exec format error" 
   - Issues appearing after changing development machines or Docker environments

2. **Particularly Problematic Modules**:
   - bcrypt: A common password-hashing library with native dependencies
   - node-gyp based modules: Many modules that require compilation
   - Modules with C/C++ bindings

### Prevention and Solutions

1. **Use Pure JavaScript Alternatives**:
   - bcryptjs: Pure JS implementation of bcrypt
   - Other pure JS modules when available

2. **Ensure Proper Build Environment**:
   - Include proper build tools in your Dockerfile:
     ```dockerfile
     # Install build essentials
     RUN apk add --no-cache python3 make g++ 
     ```

3. **Rebuild Native Modules**:
   - For some modules, explicitly rebuilding can help:
     ```dockerfile
     RUN npm rebuild <module-name> --build-from-source
     ```

### Testing Across Architectures

1. **Test on Different Environments**:
   - Test on both x86 (Intel/AMD) and ARM (M1/M2 Mac) machines
   - Use Docker's multi-platform build capabilities for production images

2. **Local Development Checks**:
   ```powershell
   # Check container architecture
   docker exec auth-service-dev uname -m
   
   # Check Node.js binary architecture
   docker exec auth-service-dev node -p process.arch
   ```

3. **Handling Mixed Development Teams**:
   - Document architecture requirements
   - Prefer architecture-agnostic dependencies
   - Consider using Docker multi-platform images

For a detailed case study on solving bcrypt architecture issues in this project, see the [BcryptArchitectureCompatibility.md](../DebugTrack/BcryptArchitectureCompatibility.md) document in the DebugTrack folder.

## Troubleshooting Common Issues

### Docker Issues on Windows

1. **Port Conflicts**:
   - Error: "port is already allocated"
   - Solution: Stop conflicting services or change mapped ports in docker-compose files

2. **Volume Mount Issues**:
   - Error: "Error response from daemon: error while creating mount source path"
   - Solution: Check Docker file sharing settings, ensure path exists and has correct permissions

3. **Network Connection Issues**:
   - Problem: Services unable to communicate
   - Solution: Check network configuration, use service names for container-to-container communication

### MongoDB Connection Issues

1. **Authentication Failures**:
   - Error: "MongoError: Authentication failed"
   - Solutions:
     - Check username/password in connection string
     - Verify MongoDB is running with authentication enabled
     - Check if user exists and has correct permissions

2. **Connection Refused**:
   - Error: "MongoNetworkError: connect ECONNREFUSED"
   - Solutions:
     - Check if MongoDB container is running
     - Verify connection string uses correct host/port
     - In Docker, ensure you're using the service name (`mongodb`) not localhost

### Email Testing Issues

1. **MailHog Not Receiving Emails**:
   - Check MailHog container is running: `docker ps | findstr mailhog`
   - Verify application is using correct SMTP settings (host: `mailhog`, port: `1025`)
   - Check application logs for email sending errors

2. **Real Email Not Working**:
   - Check SMTP server settings (host, port, TLS settings)
   - Verify email credentials
   - Check if your SMTP provider blocks automated emails

### Jest Test Failures

1. **Test Timeout Issues**:
   - Increase Jest timeout in test files: `jest.setTimeout(30000);`
   - Check for network connectivity issues
   - Look for stuck async operations

2. **Authentication Test Failures**:
   - Verify JWT secrets are configured correctly
   - Check token expiration times
   - Ensure user credentials in tests are valid

For any issues not covered here, check application logs:
```powershell
# View logs for auth service
docker-compose -f docker-compose.dev.yml logs auth-service

# View MongoDB logs
docker-compose -f docker-compose.dev.yml logs mongodb

# View MailHog logs
docker-compose -f docker-compose.dev.yml logs mailhog
```