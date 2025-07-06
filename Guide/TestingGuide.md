# Comprehensive Testing Guide

This guide provides detailed instructions for testing the TypeScript Authentication System in different environments, with a special focus on Windows Docker-based development and testing.

## Table of Contents

1. [Development Testing in Docker](#development-testing-in-docker)
2. [Manual Testing with MailHog](#manual-testing-with-mailhog)
3. [Automated Testing](#automated-testing)
4. [Production Deployment Testing](#production-deployment-testing)
5. [Real Email Verification Testing](#real-email-verification-testing)
6. [Testing Admin User Creation API](#testing-admin-user-creation-api)
7. [Testing Admin Authentication and Authorization](#testing-admin-authentication-and-authorization)
8. [Testing Admin User Deletion Functionality](#testing-admin-user-deletion-functionality)
9. [Architecture Compatibility Issues](#architecture-compatibility-issues)
10. [Troubleshooting Common Issues](#troubleshooting-common-issues)
11. [Understanding Deployment Test Reports](#understanding-deployment-test-reports)

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
   - API Endpoint: <http://localhost:3000/api>
   - MailHog UI: <http://localhost:8025>

### Force Rebuilding Docker Containers

When you need to ensure your container has the latest dependencies or configuration changes, you may need to force rebuild:

1. **Rebuild All Services**:

   ```powershell
   # Force rebuild and start development containers
   docker-compose -f docker-compose.dev.yml up --build
   
   # For detached mode
   docker-compose -f docker-compose.dev.yml up -d --build
   ```

2. **Rebuild a Specific Service**:

   ```powershell
   # Rebuild only the auth-service
   docker-compose -f docker-compose.dev.yml build auth-service
   
   # Then start the services
   docker-compose -f docker-compose.dev.yml up
   ```

3. **Rebuild and Run Test Service**:

   ```powershell
   # Rebuild and run the test service
   docker-compose -f docker-compose.dev.yml run --rm --build auth-test
   
   # Run specific tests after rebuilding
   docker-compose -f docker-compose.dev.yml run --rm --build auth-test npm test -- -t "Role-Based Access Control Tests"
   ```

4. **Complete Clean Rebuild**:

   ```powershell
   # Stop and remove all containers, networks, and volumes
   docker-compose -f docker-compose.dev.yml down -v
   
   # Remove any dangling images
   docker system prune -f
   
   # Rebuild and start from scratch
   docker-compose -f docker-compose.dev.yml up --build
   ```

#### When to Force Rebuild

- After updating dependencies in package.json
- When switching between different development environments (x86/ARM)
- After modifying Dockerfile.dev or docker-compose configuration
- When troubleshooting native Node.js module issues like bcrypt
- When making significant changes to the application structure

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
   - Open <http://localhost:8025> in your browser

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
   HOST_URL=https://your-domain.com
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

## Testing Admin Authentication and Authorization

### Admin Credentials Setup for Testing

When testing the admin functionality of the system, you'll need to access endpoints that require admin privileges. Here's how to set up and test admin credentials:

#### Setting Up an Admin User for Testing

1. **Initial Admin User Creation**:

   There's no initial admin user seeded in the database by default. For testing, you need to create one:

   ```bash
   # First, create a regular user through the signup endpoint
   curl -X POST http://localhost:3000/api/auth/signup \
     -H "Content-Type: application/json" \
     -d '{
       "username": "admin",
       "email": "admin@example.com",
       "password": "AdminPassword123!"
     }'
   ```

2. **Convert the User to Admin**:

   You must update the user's role directly in the database. This is by design - even admin users cannot create other admin users through the API to prevent privilege escalation.

   ```bash
   # Access the MongoDB container
   docker exec -it auth-mongodb mongosh
   
   # In the MongoDB shell:
   use auth_db
   
   # Update the user role and verify the email (both required steps)
   db.users.updateOne(
     { username: "admin" },
     { $set: { role: "admin", isVerified: true } }
   )
   
   # You should see the confirmation:
   # { "acknowledged": true, "matchedCount": 1, "modifiedCount": 1 }
   
   # Verify the update was successful:
   db.users.findOne({ username: "admin" })
   
   # Exit MongoDB shell
   exit
   ```

   **Why this works**: The User model in MongoDB has a `role` field that defaults to "enduser". By updating this field to "admin", you're granting the user admin privileges. The `isVerified` field needs to be set to true to allow the user to log in.

#### Using the Deploy Test Script with Admin Testing

The `deploy_test.py` script includes support for testing admin functionality:

```bash
# Run the deployment tests including admin API testing
python deploy_test.py --url http://localhost:3000 --admin-test true
```

When running with the `--admin-test` flag:

1. The script will attempt to log in with default admin credentials (`admin`/`AdminPassword123!`)
2. If that fails, it will prompt for admin credentials
3. After successful login, it will test admin-specific endpoints:
   - Creating new users with different roles
   - Listing all users in the system

#### Understanding the Admin Test Failures

If the admin test fails with `[FAIL] Admin Login`, it's typically because:

1. **No admin user exists**: Follow the steps above to create one
2. **Wrong credentials**: Verify the username and password
3. **Admin user is not verified**: Check the `isVerified` field in the database

### Testing Role-Based Access Control

The system has four roles with a hierarchical permission structure:

1. `admin`: Full system access
2. `supervisor`: Limited administrative features
3. `enduser`: Basic functionality only
4. `user`: Alias for `enduser`, providing the same basic functionality

To test this hierarchy:

```bash
# Create test users with different roles
python deploy_test.py --url http://localhost:3000 --admin-test true
```

#### Understanding How Roles Work in the Codebase

The role-based system works through:

1. **Role Storage**: Roles are stored in the User document in MongoDB

   ```javascript
   // In user.model.ts:
   export enum UserRole {
     ADMIN = 'admin',
     SUPERVISOR = 'supervisor',
     ENDUSER = 'enduser',
     USER = 'user'  // USER is an alias for ENDUSER
   }
   ```

2. **JWT Token Inclusion**: When tokens are generated, the role is included:

   ```javascript
   // In token.service.ts:
   const payload = { sub: userId, username, type: 'access', role };
   ```

3. **Middleware Protection**: Routes are protected by role-checking middleware:

   ```javascript
   // In auth.middleware.ts
   export const requireAdmin = (req, res, next) => {
     if (req.user.role !== UserRole.ADMIN) {
       return res.status(403).json({ error: 'Admin access required' });
     }
     next();
   };
   ```

Understanding these components helps in debugging authorization issues during testing.

### Troubleshooting Admin Authentication

If you encounter issues with admin authentication during testing:

1. **Database Role Verification**:

   ```bash
   docker exec -it auth-mongodb mongosh
   use auth_db
   db.users.find({ username: "admin" }).pretty()
   ```

   Ensure that `role` is set to "admin" and `isVerified` is `true`.

2. **API Response Debugging**:
   Add verbose logging to your test requests:

   ```bash
   curl -v -X POST http://localhost:3000/api/auth/login \
     -H "Content-Type: application/json" \
     -d '{"username":"admin","password":"AdminPassword123!"}'
   ```

3. **Token Validation**:
   Decode a JWT token to check role inclusion:

   ```bash
   npm install -g jwt-cli
   jwt decode YOUR_TOKEN
   ```

   Verify that the payload contains `"role": "admin"`.

Remember that any change to the role system requires updates to the role enumeration, middleware, and potentially the database schema to ensure consistent behavior.

## Testing Admin User Deletion Functionality

The authentication system now includes endpoints for admin users to delete individual users or perform bulk user deletion. This section covers how to test these features to ensure they're working correctly.

### Testing Individual User Deletion

First, create some test users that you can delete:

1. **Create Test Users to Delete**:

   ```powershell
   # Login as admin
   $adminLoginResponse = Invoke-RestMethod -Uri 'http://localhost:3000/api/auth/login' -Method Post -ContentType 'application/json' -Body '{"username":"admin","password":"AdminPassword123!"}'
   
   # Extract admin token
   $adminToken = $adminLoginResponse.accessToken
   
   # Create users for deletion testing
   $deleteTestUser = Invoke-RestMethod -Uri 'http://localhost:3000/api/admin/users' -Method Post -Headers @{
       "Authorization" = "Bearer $adminToken"
   } -ContentType 'application/json' -Body '{
       "username": "deletetest", 
       "email": "deletetest@example.com", 
       "password": "Password123!", 
       "role": "user",
       "skipVerification": true
   }'
   
   # Store the user ID for deletion
   $userIdToDelete = $deleteTestUser.userId
   ```

2. **Delete a Single User**:

   ```powershell
   # Delete the test user
   $deleteResponse = Invoke-RestMethod -Uri "http://localhost:3000/api/admin/users/$userIdToDelete" -Method Delete -Headers @{
       "Authorization" = "Bearer $adminToken"
   }
   
   # Check the response
   $deleteResponse
   ```

3. **Verify Deletion**:

   ```powershell
   # List all users to confirm deletion
   $usersAfterDeletion = Invoke-RestMethod -Uri 'http://localhost:3000/api/admin/users' -Method Get -Headers @{
       "Authorization" = "Bearer $adminToken"
   }
   
   # Check if the deleted user is gone
   $deletedUserExists = $usersAfterDeletion.users | Where-Object { $_.username -eq "deletetest" }
   
   if ($deletedUserExists) {
       Write-Host "ERROR: User still exists after deletion attempt"
   } else {
       Write-Host "SUCCESS: User was deleted successfully"
   }
   ```

### Testing Security Restrictions

The user deletion API includes important security restrictions that should be tested:

1. **Attempt to Delete Self (Should Fail)**:

   ```powershell
   # Get admin's own user ID
   $adminProfile = Invoke-RestMethod -Uri 'http://localhost:3000/api/protected/profile' -Method Get -Headers @{
       "Authorization" = "Bearer $adminToken"
   }
   $adminUserId = $adminProfile.user._id
   
   # Attempt to delete self (should fail)
   try {
       $selfDeleteResponse = Invoke-RestMethod -Uri "http://localhost:3000/api/admin/users/$adminUserId" -Method Delete -Headers @{
           "Authorization" = "Bearer $adminToken"
       }
       Write-Host "ERROR: Self-deletion should not be allowed"
   } catch {
       $statusCode = $_.Exception.Response.StatusCode.value__
       Write-Host "Expected error occurred: Cannot delete self (Status code: $statusCode)"
   }
   ```

2. **Attempt to Delete Another Admin (Should Fail)**:

   ```powershell
   # First create another admin directly in the database
   # This requires direct database access as the API doesn't allow creating admins
   
   # Then attempt to delete the other admin (should fail)
   try {
       $otherAdminDeleteResponse = Invoke-RestMethod -Uri "http://localhost:3000/api/admin/users/$otherAdminId" -Method Delete -Headers @{
           "Authorization" = "Bearer $adminToken"
       }
       Write-Host "ERROR: Deleting another admin should not be allowed"
   } catch {
       $statusCode = $_.Exception.Response.StatusCode.value__
       Write-Host "Expected error occurred: Cannot delete other admin (Status code: $statusCode)"
   }
   ```

### Testing Bulk User Deletion

The bulk deletion endpoint is powerful and should be tested carefully:

1. **Create Multiple Test Users**:

   ```powershell
   # Create several test users
   for ($i = 1; $i -le 5; $i++) {
       $bulkTestUser = Invoke-RestMethod -Uri 'http://localhost:3000/api/admin/users' -Method Post -Headers @{
           "Authorization" = "Bearer $adminToken"
       } -ContentType 'application/json' -Body "{
           `"username`": `"bulktest$i`", 
           `"email`": `"bulktest$i@example.com`", 
           `"password`": `"Password123!`", 
           `"role`": `"user`",
           `"skipVerification`": true
       }"
   }
   
   # Check how many users exist before bulk deletion
   $usersBefore = Invoke-RestMethod -Uri 'http://localhost:3000/api/admin/users' -Method Get -Headers @{
       "Authorization" = "Bearer $adminToken"
   }
   $countBefore = $usersBefore.users.Count
   Write-Host "Users before bulk deletion: $countBefore"
   ```

2. **Bulk Delete with Confirmation**:

   ```powershell
   # Perform bulk deletion with preserveAdmins=true (default)
   $bulkDeleteResponse = Invoke-RestMethod -Uri 'http://localhost:3000/api/admin/users' -Method Delete -Headers @{
       "Authorization" = "Bearer $adminToken"
   } -ContentType 'application/json' -Body '{
       "confirmDelete": "DELETE_ALL_USERS"
   }'
   
   # Check the response
   $bulkDeleteResponse
   ```

3. **Verify Bulk Deletion**:

   ```powershell
   # Check how many users exist after bulk deletion
   $usersAfter = Invoke-RestMethod -Uri 'http://localhost:3000/api/admin/users' -Method Get -Headers @{
       "Authorization" = "Bearer $adminToken"
   }
   $countAfter = $usersAfter.users.Count
   Write-Host "Users after bulk deletion: $countAfter"
   
   # Should only have admin users remaining
   $nonAdminUsers = $usersAfter.users | Where-Object { $_.role -ne "admin" }
   if ($nonAdminUsers) {
       Write-Host "ERROR: Non-admin users still exist after bulk deletion"
   } else {
       Write-Host "SUCCESS: All non-admin users were deleted"
   }
   ```

### Testing with curl (Bash/Git Bash)

For bash users, here are the curl commands to test user deletion:

```bash
# Login as admin
admin_response=$(curl -s -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"AdminPassword123!"}')
  
# Extract token
admin_token=$(echo $admin_response | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4)

# Create a test user to delete
create_response=$(curl -s -X POST http://localhost:3000/api/admin/users \
  -H "Authorization: Bearer $admin_token" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "deletetest",
    "email": "deletetest@example.com",
    "password": "Password123!",
    "role": "user",
    "skipVerification": true
  }')
  
# Extract user ID
user_id=$(echo $create_response | grep -o '"userId":"[^"]*"' | cut -d'"' -f4)

# Delete the test user
curl -X DELETE http://localhost:3000/api/admin/users/$user_id \
  -H "Authorization: Bearer $admin_token"

# Bulk delete all non-admin users
curl -X DELETE http://localhost:3000/api/admin/users \
  -H "Authorization: Bearer $admin_token" \
  -H "Content-Type: application/json" \
  -d '{
    "confirmDelete": "DELETE_ALL_USERS"
  }'
```

### Common Issues and Troubleshooting

1. **Missing Confirmation for Bulk Delete**:
   - If you get a 400 error when attempting bulk deletion, check that you've included the exact confirmation string: `"confirmDelete": "DELETE_ALL_USERS"`
   - Example error: `{"error":"Confirmation required","message":"To delete all users, include {\"confirmDelete\": \"DELETE_ALL_USERS\"} in the request body"}`

2. **Cannot Delete Admin Users**:
   - The system prevents admins from deleting other admins by design
   - If you need to delete an admin account, you must do it directly in the database

3. **Tokens Remaining After User Delete**:
   - When a user is deleted, their refresh tokens should be automatically cleaned up
   - If you experience token-related issues after deletion, check the MongoDB Token collection:

     ```bash
     docker exec -it auth-mongodb mongosh
     use auth_db
     db.tokens.find({ userId: ObjectId("deleted-user-id") })
     ```

4. **Permission Issues**:
   - Only admin users can delete users
   - Regular users or supervisors attempting to delete users will receive a 403 Forbidden error

By following these testing procedures, you can ensure that the user deletion functionality works correctly and securely in your authentication system.

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

## Understanding Deployment Test Reports

The `deploy_test.py` script generates detailed JSON reports that provide valuable insight into your authentication system's functionality. These reports are automatically saved in the `tests` directory with timestamped filenames (e.g., `deploy_test_report_20250410_153937.json`).

### Example Test Report

Here's an example of what a test report looks like:

```json
{
  "api_url": "http://localhost:3000",
  "test_date": "2025-04-10 15:39:37",
  "passed": 9,
  "total": 10,
  "pass_rate": 90.0,
  "results": [
    {
      "test": "Health Check",
      "passed": true,
      "timestamp": "2025-04-10 15:38:43"
    },
    {
      "test": "User Sign Up",
      "passed": true,
      "timestamp": "2025-04-10 15:38:43",
      "details": "User ID: 67f7758352bcb71ef4800533"
    },
    {
      "test": "Email Verification",
      "passed": true,
      "timestamp": "2025-04-10 15:39:04",
      "details": "Status code: 200, Response: {\"message\":\"Email verified successfully\"}"
    },
    {
      "test": "User Login",
      "passed": true,
      "timestamp": "2025-04-10 15:39:04",
      "details": "Tokens received"
    },
    {
      "test": "Access Protected Route",
      "passed": true,
      "timestamp": "2025-04-10 15:39:04",
      "details": "Status code: 200, Response: {\"user\":{\"_id\":\"67f7758352bcb71ef4800533\",\"username\":\"testuser_0ad2a571\",\"email\":\"test.0ad2a571@exam..."
    },
    {
      "test": "Refresh Token",
      "passed": false,
      "timestamp": "2025-04-10 15:39:04",
      "details": "Token refresh failed"
    },
    {
      "test": "Request Password Reset",
      "passed": true,
      "timestamp": "2025-04-10 15:39:22",
      "details": "Status code: 200, Response: {\"message\":\"If your email exists in our system, you will receive a password reset link\"}"
    },
    {
      "test": "Password Reset",
      "passed": true,
      "timestamp": "2025-04-10 15:39:37",
      "details": "Status code: 200, Response: {\"message\":\"Password reset successful\"}"
    },
    {
      "test": "User Login",
      "passed": true,
      "timestamp": "2025-04-10 15:39:37",
      "details": "Tokens received"
    },
    {
      "test": "User Logout",
      "passed": true,
      "timestamp": "2025-04-10 15:39:37",
      "details": "Status code: 200, Response: {\"message\":\"Logout successful\"}"
    }
  ]
}
```

### Analyzing Test Results

The report provides an overall summary (pass rate, total tests) and detailed results for each test case:

1. **Test Name**: Indicates which functionality was tested
2. **Passed Status**: Whether the test passed (`true`) or failed (`false`)
3. **Timestamp**: When the test was executed
4. **Details**: Response data or error information

### Identifying and Fixing Common Issues

#### Token Refresh Failures

In the example report, the "Refresh Token" test failed. This is a common issue that could be caused by:

1. **JWT Secret Mismatch**: Verify that `JWT_REFRESH_SECRET` is consistently set across all environments
2. **Token Expiration Configuration**: Check that `JWT_REFRESH_EXPIRES_IN` is properly configured
3. **Database Storage Issues**: Ensure refresh tokens are properly stored in the database
4. **Token Service Implementation**: Review `token.service.ts` for any implementation issues

To troubleshoot:

```bash
# Check environment variables in your running container
docker exec auth-service-dev printenv | grep JWT

# View token service logs
docker logs auth-service-dev | grep "token service"

# Check for MongoDB connectivity issues
docker logs auth-service-dev | grep "MongoDB"
```

#### Email Verification Issues

If the "Email Verification" test fails:

1. **Check MailHog UI**: Visit <http://localhost:8025> to see if verification emails are being sent
2. **Verify Token Generation**: Look for logs about verification token creation
3. **Database Connectivity**: Ensure the Verification model can access MongoDB

#### User Registration Problems

If "User Sign Up" fails:

1. **Database Connection**: Verify MongoDB is accessible
2. **Unique Constraints**: Check if username/email already exists
3. **Validation Rules**: Ensure password meets complexity requirements

### Running Tests with Different Parameters

To focus on specific issues, you can run the deploy test with various options:

```bash
# Run only authentication tests
python deploy_test.py --url http://localhost:3000 --auth-only

# Run tests with verbose output
python deploy_test.py --url http://localhost:3000 --verbose

# Run admin-specific tests
python deploy_test.py --url http://localhost:3000 --admin-test true
```

### Tracking Report History

Keeping historical test reports is valuable for tracking system stability:

```bash
# Create a reports directory
mkdir -p test-reports

# Copy reports with timestamp-based organization
cp tests/deploy_test_report_*.json test-reports/

# Compare latest report with previous
diff test-reports/deploy_test_report_20250410_153937.json test-reports/deploy_test_report_20250410_161045.json
```

### Automated Report Analysis

For continuous integration, you can create a script to analyze reports:

```python
import json
import sys
import glob
import os

def analyze_reports(directory="./tests"):
    reports = glob.glob(f"{directory}/deploy_test_report_*.json")
    reports.sort(key=os.path.getmtime, reverse=True)
    
    if not reports:
        print("No test reports found")
        return 1
    
    # Load latest report
    with open(reports[0], 'r') as f:
        latest = json.load(f)
    
    print(f"Latest report: {os.path.basename(reports[0])}")
    print(f"Pass rate: {latest['pass_rate']}%")
    
    # Find failed tests
    failures = [r for r in latest['results'] if not r['passed']]
    if failures:
        print("\nFailed tests:")
        for failure in failures:
            print(f"  - {failure['test']}: {failure.get('details', 'No details')}")
        return 1
    
    print("All tests passed!")
    return 0

if __name__ == "__main__":
    sys.exit(analyze_reports())
```

## Troubleshooting Common Test Failures
