# Authentication System Testing Guide

This document provides detailed instructions for running and understanding the various test scripts in this authentication system. It's designed to complement the testing section in the README.md with more examples and practical usage scenarios.

## Test Files Overview

| File | Description | Best Used For |
|------|-------------|--------------|
| `tests/auth.test.ts` | Jest unit tests for core auth functions | CI/CD pipelines, development validation |
| `tests/auth-api-tests.ps1` | PowerShell API testing script | Windows comprehensive API testing |
| `tests/auto-verify-tests.ps1` | PowerShell script with auto email verification | Testing without email client access |
| `tests/auth-api-curl-tests.sh` | Bash/curl script for API testing | Linux/macOS or Git Bash API testing |

## Testing in Windows Docker Environment

### Setting Up the Environment

1. Start the Docker containers:

   ```powershell
   cd "c:\path\to\simple-accounting"
   docker-compose -f docker-compose.dev.yml up -d
   ```

2. Verify containers are running:

   ```powershell
   docker ps
   ```

   You should see containers for:
   - Authentication service
   - MongoDB
   - MailHog (if configured)

### Running PowerShell Tests (auth-api-tests.ps1)

This script tests all authentication endpoints sequentially with detailed feedback:

```powershell
# Make sure you're in the project directory
cd "c:\path\to\simple-accounting"

# Run the full test suite
.\tests\auth-api-tests.ps1
```

**What this tests:**

- User signup
- User login
- Token refresh
- Password reset flow
- Protected routes
- Admin routes
- Logout functionality

**Output:**

- Terminal output with color-coded results
- JSON files in `tests\curl-tests\` directory containing API responses

**Configuration options:**
Edit the script to change:

- Base URL (`$baseUrl = "http://localhost:3000"`)
- Test user credentials

### Running Automated Email Verification Tests (auto-verify-tests.ps1)

This script focuses on testing the full authentication flow with automated email verification:

```powershell
# Make sure you're in the project directory
cd "c:\path\to\simple-accounting"

# Run the automated verification test
.\tests\auto-verify-tests.ps1
```

**What this tests:**

- User signup
- Automatic email verification without manual intervention
- Login with verified account
- Access to protected resources

**How it works:**

1. Creates a test user
2. Uses the testing API to retrieve the verification token
3. Automatically verifies the email
4. Tests login and protected routes

**When to use:**

- During active development to quickly test the auth flow
- In environments where email access is difficult
- For rapid iterative testing

### Running Bash/Curl Tests (auth-api-curl-tests.sh)

For Git Bash users on Windows or Linux/macOS environments:

```bash
# Make sure you're in the project directory
cd /c/path/to/simple-accounting

# Make the script executable (first time only)
chmod +x ./tests/auth-api-curl-tests.sh

# Run the script
./tests/auth-api-curl-tests.sh
```

**What this tests:**

- Same endpoints as the PowerShell script
- Focused on curl command usage
- Saves all responses for inspection

**Output:**

- Terminal output with color-coded results
- JSON files in `tests/curl-results/` directory

### Running Jest Tests (auth.test.ts)

For unit testing the core authentication logic:

```powershell
# In PowerShell or Command Prompt
npm test

# Or to run specific tests
npm test -- -t "auth service"
```

## Special Testing Scenarios

### 1. Testing Without Email Access

If you don't have access to the email system (MailHog or real email):

1. Use `auto-verify-tests.ps1` which bypasses email verification
2. The script uses the testing API to directly verify accounts

### 2. Testing Admin Functionality

To test admin routes:

1. First create a regular user with `auth-api-tests.ps1`
2. Connect to MongoDB and update the user's role:

   ```javascript
   // In MongoDB shell
   db.users.updateOne(
     { username: "testuser12345" },
     { $set: { role: "ADMIN" } }
   )
   ```

3. Run the admin tests section again

### 3. Testing in CI/CD Pipelines

For automated testing in CI/CD:

1. Use the Jest tests (`auth.test.ts`)
2. Configure environment variables in your CI/CD platform
3. Add this to your pipeline configuration:

   ```yaml
   # Example GitHub Actions step
   - name: Run tests
     run: npm test
     env:
       NODE_ENV: test
       MONGO_URI: mongodb://localhost:27017/auth-test
       JWT_ACCESS_SECRET: test-secret
       JWT_REFRESH_SECRET: test-refresh-secret
       BYPASS_EMAIL_VERIFICATION: true
   ```

## Testing API Endpoints Individually

If you want to test specific endpoints manually:

### Signup Endpoint (PowerShell)

```powershell
$body = @{
  username = "testuser123"
  email = "test@example.com"
  password = "SecurePassword123!"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:3000/api/auth/signup" -Method Post -ContentType "application/json" -Body $body
```

### Login Endpoint (PowerShell)

```powershell
$body = @{
  username = "testuser123"
  password = "SecurePassword123!"
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri "http://localhost:3000/api/auth/login" -Method Post -ContentType "application/json" -Body $body
$token = $response.accessToken
```

### Accessing Protected Routes (PowerShell)

```powershell
$headers = @{
  "Authorization" = "Bearer $token"
}

Invoke-RestMethod -Uri "http://localhost:3000/api/protected/profile" -Method Get -Headers $headers
```

## MailHog Email Testing Pipeline

This project includes a dedicated testing pipeline for email verification using MailHog. This section provides detailed information about this testing approach, when to use it, and how it works.

### What is MailHog and Why Use It?

MailHog is a lightweight email testing tool that:

- Captures all outgoing emails during development and testing
- Provides a web interface to view and inspect email content
- Offers an API for automated testing of email functionality
- Runs as a simple Docker container requiring no configuration

Using MailHog allows you to test the complete email verification and password reset flows without sending real emails. This is particularly valuable for:

1. **Development environments** - No need for real email server configuration
2. **Automated testing** - Test email flows programmatically
3. **CI/CD pipelines** - Validate email functionality in continuous integration
4. **Visual template testing** - Preview how email templates actually render

### MailHog Testing Components

The MailHog testing pipeline consists of three main components:

#### 1. Docker Environment (`docker-compose.mailhog-test.yml`)

This Docker Compose file creates an isolated testing environment specifically for email testing:

```yaml
services:
  auth-service-mailhog-test:
    # Application service configured for MailHog testing
    environment:
      - EMAIL_HOST=mailhog
      - EMAIL_PORT=1025
      # ...other settings
  
  mongodb:
    # MongoDB service for test data
  
  mailhog:
    # MailHog service to capture and store emails
    ports:
      - "1026:1025"  # SMTP port
      - "8026:8025"  # Web UI port
```

This configuration:

- Uses separate port mappings (3001, 8026, 1026) to avoid conflicts with development environment
- Configures the application to send emails to MailHog
- Runs on a separate MongoDB database to isolate test data

#### 2. PowerShell Test Script (`mailhog-email-tests.ps1`)

This script performs comprehensive testing of email-dependent features:

- User registration with verification email
- Extraction of verification tokens from emails in MailHog
- Email verification with the extracted token
- Login with the verified account
- Password reset flow using MailHog

It communicates with both your authentication API and the MailHog API to test the entire email verification flow.

#### 3. Jest Email Tests (`email.test.ts`)

These tests provide programmatic validation of email functionality:

- Test email sending during user registration
- Validate email content and format
- Test verification token extraction and usage
- Verify the complete password reset flow

### When to Use Each Testing Method

| Testing Need | Recommended Method | Why |
|--------------|-------------------|-----|
| Quick API validation | `auto-verify-tests.ps1` | Bypasses email flow for rapid testing |
| Complete flow testing | `mailhog-email-tests.ps1` | Tests real email delivery and content |
| Email template testing | MailHog UI (localhost:8026) | Visual inspection of email content |
| CI/CD integration | `npm run test:mailhog` | Programmatic validation with Jest |
| Debugging email issues | MailHog UI + `mailhog-email-tests.ps1` | Combines visual and automated testing |

### Running the MailHog Tests

#### Method 1: Using Docker Compose with MailHog Test Configuration

```powershell
# Start the MailHog test environment (do this first)
docker-compose -f docker-compose.mailhog-test.yml up -d

# Option 1: Run the PowerShell MailHog email tests
npm run mailhog:test

# Option 2: Run the Jest email tests
npm run test:mailhog

# When finished, stop the environment
docker-compose -f docker-compose.mailhog-test.yml down
```

#### Method 2: Using MailHog in Development Environment

The regular development environment (`docker-compose.dev.yml`) also includes MailHog. You can:

1. Start the development environment with `docker-compose -f docker-compose.dev.yml up -d`
2. Access MailHog at <http://localhost:8025>
3. Manually test email functionality by registering users and checking the emails

### How the MailHog Tests Work

#### 1. PowerShell Script Workflow

1. **User Registration**: Creates a new test user via API
2. **Email Monitoring**: Polls the MailHog API to detect the verification email
3. **Token Extraction**: Parses the email content to extract the verification token
4. **Email Verification**: Calls the verification API with the extracted token
5. **Login Testing**: Confirms login works after verification
6. **Password Reset**: Tests the complete password reset flow with email

The script uses these key PowerShell functions:

- `Get-MailhogMessages`: Retrieves emails from MailHog API
- `Extract-VerificationTokenFromEmail`: Parses email content for tokens
- `Clear-MailhogMessages`: Cleans the MailHog inbox between tests

#### 2. Jest Tests Integration

The Jest tests use:

- `mongodb-memory-server` for database testing
- `supertest` for API requests
- `axios` for MailHog API communication
- Mocked `nodemailer` transporter for email sending

### Troubleshooting MailHog Tests

#### Common Issues and Solutions

1. **Cannot connect to MailHog API**:
   - Verify MailHog container is running: `docker ps | findstr mailhog`
   - Check port mapping in docker-compose file
   - Try accessing the web UI at <http://localhost:8026>

2. **Emails not appearing in MailHog**:
   - Verify email settings in environment variables
   - Check application logs for email sending errors
   - Ensure `nodemailer` is configured to use MailHog

3. **Token extraction failing**:
   - Inspect actual email content via MailHog UI
   - Adjust regex patterns in `Extract-VerificationTokenFromEmail` function
   - Increase retry count or delay between retries

4. **Jest tests failing with MailHog**:
   - Install missing dependencies (`mongodb-memory-server`, `axios`)
   - Check for TypeScript path issues in imports
   - Use `--detectOpenHandles` flag to identify hanging connections

### Extending the MailHog Tests

You can extend the MailHog testing pipeline for additional scenarios:

1. **Testing custom email templates**:
   - Add new test cases that trigger different email types
   - Validate content and formatting of each template

2. **Testing email delivery failures**:
   - Simulate failure scenarios by stopping MailHog during tests
   - Verify application handles email failures gracefully

3. **Load testing email processing**:
   - Generate multiple registrations in parallel
   - Measure system performance under email processing load

## Cross-Environment Testing Approaches

Here's a comparison of testing approaches across different environments:

| Environment | Testing Approach | Email Handling | Best For |
|-------------|-----------------|---------------|----------|
| Development | Manual + auto-verify | MailHog (localhost:8025) | Interactive development |
| Test/CI | Jest + mailhog-tests | MailHog (isolated) | Automated verification |
| Staging | End-to-end tests | Real email (test accounts) | Pre-production validation |
| Production | Monitoring | Real email (actual users) | Live system verification |

By following this testing strategy, you can ensure your authentication system's email functionality works correctly before deploying to production.

## Troubleshooting Common Testing Issues

### 1. "Connection refused" errors

**Possible causes and solutions:**

- Docker containers not running - check with `docker ps`
- Wrong port mapping - verify with `docker-compose -f docker-compose.dev.yml ps`
- Firewall blocking connections - temporarily disable or add exception
- Wrong base URL - try `host.docker.internal` instead of `localhost`

### 2. Authentication failures

**Possible causes and solutions:**

- User not verified - use `auto-verify-tests.ps1`
- Wrong credentials - check username/password in test scripts
- Token expired - refresh token or login again
- Missing Authorization header - check header format (`Bearer token`)

### 3. Email verification issues

**Possible causes and solutions:**

- MailHog not running - check with `docker ps | findstr mailhog`
- Email service misconfigured - check `.env.development` file
- Using production email in development - use test email accounts
- Use testing routes for automated verification

### 4. MongoDB connection issues

**Possible causes and solutions:**

- MongoDB container not running - check with `docker ps | findstr mongo`
- Wrong connection string - check in `.env` files
- Database initialization failed - check MongoDB logs

## Windows-Specific Testing Considerations

1. **PowerShell Execution Policy**: If PowerShell blocks script execution:

   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```

2. **Line Endings**: If scripts have wrong line endings:

   ```powershell
   # Convert to Windows line endings
   (Get-Content .\tests\auth-api-tests.ps1 -Raw).Replace("`n", "`r`n") | Set-Content .\tests\auth-api-tests.ps1 -Force
   ```

3. **Docker Desktop Settings**: Ensure resources are sufficient:
   - Open Docker Desktop → Settings → Resources
   - Allocate at least 2GB RAM and 2 CPUs

4. **Network Access**: If using WSL2 backend with Docker:
   - Use `host.docker.internal` instead of `localhost`
   - Or use explicit IP addresses

## Extending the Test Suite

To add additional tests:

1. For PowerShell/curl tests:
   - Copy existing test patterns in the scripts
   - Add new endpoint tests following the same structure
   - Update response handling as needed

2. For Jest tests:
   - Add new test cases to `auth.test.ts`
   - Follow the existing pattern of `describe` and `it` blocks
   - Use mock functions for external dependencies

## Conclusion

This test suite provides comprehensive coverage of the authentication system's functionality. By using these tools appropriately, you can ensure that your authentication system works correctly across all environments, including Docker on Windows.

For any questions or issues with the testing framework, please open an issue on the project repository.
