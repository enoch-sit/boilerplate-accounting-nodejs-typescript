# Comprehensive Authentication System Testing Guide

This document provides detailed instructions for testing the authentication system across different environments, with special focus on the Windows testing pipeline.

## Table of Contents

1. [Overview](#overview)
2. [Testing Environment Setup](#testing-environment-setup)
3. [Windows Testing Pipeline](#windows-testing-pipeline)
4. [Test Components and Scripts](#test-components-and-scripts)
5. [MailHog Email Testing](#mailhog-email-testing)
6. [API Endpoint Testing](#api-endpoint-testing)
7. [Unit Testing](#unit-testing)
8. [Environment-Specific Testing](#environment-specific-testing)
9. [Troubleshooting](#troubleshooting)
10. [Extending the Test Suite](#extending-the-test-suite)
11. [Continuous Integration](#continuous-integration)

## Overview

The authentication system includes a comprehensive testing strategy covering:

1. **Unit Tests**: Core functionality tests using Jest
2. **Docker Environment Verification**: Ensures containers are running properly
3. **MailHog Functionality Tests**: Validates email testing infrastructure
4. **API Endpoint Testing**: Tests all endpoints with and without email verification
5. **Fallback Testing**: Alternative testing paths when primary services are unavailable

## Testing Environment Setup

### Prerequisites

- Windows 10/11 (for Windows pipeline)
- PowerShell 5.1 or later
- Node.js v18+ and npm
- Docker Desktop for Windows
- MongoDB (local or containerized)
- Git for Windows

### Docker Environment Setup

```powershell
# Start the development environment
docker-compose -f docker-compose.dev.yml up -d

# Verify containers are running
docker ps

# For email testing environment
docker-compose -f docker-compose.mailhog-test.yml up -d
```

You should see containers for:
- Authentication service
- MongoDB
- MailHog (for email testing)

## Windows Testing Pipeline

The Windows testing pipeline provides an automated, comprehensive approach to testing the entire authentication system from a single command.

### Pipeline Components

| Component | Purpose | File |
|-----------|---------|------|
| Main Testing Pipeline | Orchestrates the complete testing workflow | `tests/test-pipeline.ps1` |
| Docker Health Check | Verifies Docker containers are running properly | `tests/docker-health-check.ps1` |
| MailHog Check | Tests MailHog SMTP and API functionality | `tests/mailhog-check.ps1` |
| API Tests | Tests all API endpoints | `tests/auth-api-tests.ps1` |
| Email Tests with MailHog | Tests email verification with MailHog | `tests/mailhog-email-tests.ps1` |
| Automated Verification Tests | Tests API endpoints bypassing email verification | `tests/auto-verify-tests.ps1` |
| Unit Tests | Tests core functionality with Jest | `tests/auth.test.ts` and others |

### Running the Complete Pipeline

```powershell
# From project root directory
.\tests\test-pipeline.ps1
```

This will:
1. Check Node.js environment
2. Verify Docker containers are running
3. Test MailHog functionality
4. Run unit tests
5. Run API endpoint tests
6. Generate a detailed report

### Running Specific Pipeline Components

```powershell
# Run only unit tests
.\tests\test-pipeline.ps1 -UnitTestsOnly

# Run only API tests
.\tests\test-pipeline.ps1 -ApiTestsOnly

# Skip Docker checks
.\tests\test-pipeline.ps1 -SkipDockerChecks

# Run with verbose output
.\tests\test-pipeline.ps1 -Verbose
```

### Pipeline Decision Flow

The pipeline automatically adapts to your environment:

```
┌─────────────────┐
│ Start Pipeline  │
└────────┬────────┘
         ▼
┌─────────────────┐
│ Check Node.js   │
└────────┬────────┘
         ▼
┌─────────────────┐     No     ┌─────────────────┐
│ Docker Running? ├────────────► Unit Tests Only │
└────────┬────────┘            └─────────────────┘
         │ Yes
         ▼
┌─────────────────┐     No     ┌────────────────────────┐
│MailHog Available├────────────► API Tests with Direct  │
└────────┬────────┘            │ Verification Bypass    │
         │ Yes                 └────────────────────────┘
         ▼
┌─────────────────┐
│ Run Unit Tests  │
└────────┬────────┘
         ▼
┌─────────────────┐
│ Run Email Tests │
└────────┬────────┘
         ▼
┌─────────────────┐
│ Run API Tests   │
└────────┬────────┘
         ▼
┌─────────────────┐
│Generate Reports │
└─────────────────┘
```

## Test Components and Scripts

### File Overview

| File | Description | Best Used For |
|------|-------------|--------------|
| `tests/auth.test.ts` | Jest unit tests for core auth functions | CI/CD pipelines, development validation |
| `tests/email.test.ts` | Jest tests for email verification | Email template and flow testing |
| `tests/auth-api-tests.ps1` | PowerShell API testing script | Windows comprehensive API testing |
| `tests/auto-verify-tests.ps1` | PowerShell script with auto email verification | Testing without email client access |
| `tests/mailhog-email-tests.ps1` | PowerShell script for MailHog testing | Complete email verification flow testing |
| `tests/auth-api-curl-tests.sh` | Bash/curl script for API testing | Linux/macOS or Git Bash API testing |
| `tests/docker-health-check.ps1` | PowerShell script for Docker verification | Ensuring Docker environment is healthy |
| `tests/mailhog-check.ps1` | PowerShell script for MailHog verification | Testing MailHog functionality |
| `tests/test-pipeline.ps1` | Main orchestration script | Running the complete test suite |

### Running Individual Components

#### Docker Environment Check

```powershell
.\tests\docker-health-check.ps1
```

This will:
1. Check if Docker Desktop is running
2. Verify required containers are up (MongoDB, MailHog, etc.)
3. Check container health via ports and endpoints
4. Attempt to restart unhealthy containers when possible

#### MailHog Verification

```powershell
.\tests\mailhog-check.ps1
```

This will:
1. Verify MailHog API is accessible
2. Send a test email via SMTP
3. Verify the email was received correctly
4. Test email deletion functionality

#### API Endpoint Testing

```powershell
.\tests\auth-api-tests.ps1
```

This tests all authentication endpoints sequentially with detailed feedback:
- User signup
- User login
- Token refresh
- Password reset flow
- Protected routes
- Admin routes
- Logout functionality

Results are saved to JSON files in `tests\curl-tests\` directory.

#### Email Verification Tests

```powershell
.\tests\mailhog-email-tests.ps1
```

Tests the complete email verification flow including:
1. User registration
2. Email delivery to MailHog
3. Verification token extraction
4. User verification
5. Login with verified account

#### Automated Verification (No Email)

```powershell
.\tests\auto-verify-tests.ps1
```

Tests the authentication flow bypassing email verification:
1. Creates a test user
2. Uses the testing API to retrieve the verification token
3. Automatically verifies the email
4. Tests login and protected routes

#### Bash/Curl Tests

For Git Bash users on Windows or Linux/macOS environments:

```bash
# Make the script executable (first time only)
chmod +x ./tests/auth-api-curl-tests.sh

# Run the script
./tests/auth-api-curl-tests.sh
```

This tests the same endpoints as the PowerShell script using curl commands.

## MailHog Email Testing

### What is MailHog?

MailHog is a lightweight email testing tool that:
- Captures all outgoing emails during development and testing
- Provides a web interface to view and inspect email content
- Offers an API for automated testing of email functionality
- Runs as a simple Docker container requiring no configuration

### When to Use MailHog Testing

| Testing Need | Recommended Method | Why |
|--------------|-------------------|-----|
| Quick API validation | `auto-verify-tests.ps1` | Bypasses email flow for rapid testing |
| Complete flow testing | `mailhog-email-tests.ps1` | Tests real email delivery and content |
| Email template testing | MailHog UI (localhost:8025) | Visual inspection of email content |
| CI/CD integration | `npm run test:mailhog` | Programmatic validation with Jest |
| Debugging email issues | MailHog UI + `mailhog-email-tests.ps1` | Combines visual and automated testing |

### MailHog Testing Components

#### 1. Docker Environment

The system includes two MailHog configurations:

- **Development Environment** (docker-compose.dev.yml):
  - MailHog UI: http://localhost:8025
  - SMTP port: 1025
  
- **Testing Environment** (docker-compose.mailhog-test.yml):
  - MailHog UI: http://localhost:8026
  - SMTP port: 1026
  
This separation allows you to test without interfering with your development environment.

#### 2. PowerShell Testing Script

The `mailhog-email-tests.ps1` script performs comprehensive testing of email features:

- User registration with verification email
- Extraction of verification tokens from emails in MailHog
- Email verification with the extracted token
- Login with the verified account
- Password reset flow using MailHog

#### 3. Jest Email Tests

The `email.test.ts` file contains programmatic tests for email functionality:
- Tests email sending during user registration
- Validates email content and format
- Tests verification token extraction and usage
- Verifies the complete password reset flow

### Running MailHog Tests

#### Method 1: Using Docker Compose with MailHog Test Configuration

```powershell
# Start the MailHog test environment
docker-compose -f docker-compose.mailhog-test.yml up -d

# Option 1: Run the PowerShell MailHog email tests
.\tests\mailhog-email-tests.ps1

# Option 2: Run the Jest email tests
npm run test:mailhog

# When finished, stop the environment
docker-compose -f docker-compose.mailhog-test.yml down
```

#### Method 2: Using MailHog in Development Environment

```powershell
# Start the development environment
docker-compose -f docker-compose.dev.yml up -d

# Access MailHog at http://localhost:8025
start http://localhost:8025

# Manually test email functionality
```

### MailHog API Examples

```powershell
# Get all messages from MailHog
Invoke-RestMethod -Uri "http://localhost:8025/api/v2/messages"

# Delete all messages
Invoke-RestMethod -Uri "http://localhost:8025/api/v1/messages" -Method Delete
```

## API Endpoint Testing

### Testing Individual Endpoints

#### Registration Endpoint

```powershell
$body = @{
  username = "testuser123"
  email = "test@example.com"
  password = "SecurePassword123!"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:3000/api/auth/signup" -Method Post -ContentType "application/json" -Body $body
```

#### Login Endpoint

```powershell
$body = @{
  username = "testuser123"
  password = "SecurePassword123!"
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri "http://localhost:3000/api/auth/login" -Method Post -ContentType "application/json" -Body $body
$token = $response.accessToken
```

#### Accessing Protected Routes

```powershell
$headers = @{
  "Authorization" = "Bearer $token"
}

Invoke-RestMethod -Uri "http://localhost:3000/api/protected/profile" -Method Get -Headers $headers
```

### Testing Approaches

#### 1. With Email Verification (MailHog)

When MailHog is available, the full email verification flow is tested:

```powershell
# Run email verification tests with MailHog
.\tests\mailhog-email-tests.ps1
```

#### 2. Without Email Verification (Direct API)

If MailHog is unavailable or for faster testing, use direct verification:

```powershell
# Run tests with direct verification bypass
.\tests\auto-verify-tests.ps1
```

### Testing Routes for Direct Verification

For development and testing, the application includes special endpoints:

- `GET /api/testing/verification-token/:userId` - Get verification token for a user
- `POST /api/testing/verify-user/:userId` - Directly verify a user without a token

Example usage:

```powershell
# Get token for user
$userId = "user-id-from-signup"
$tokenResponse = Invoke-RestMethod -Uri "http://localhost:3000/api/testing/verification-token/$userId" -Method Get

# Use token for verification
$verifyBody = @{
    token = $tokenResponse.token
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:3000/api/auth/verify-email" -Method Post -ContentType "application/json" -Body $verifyBody
```

## Unit Testing

### Running Jest Tests

```powershell
# Run all tests
npm test

# Run with verbose output
npm test -- --verbose

# Run specific tests
npm test -- -t "auth service"
```

### Writing New Unit Tests

Create new test files in the `tests` directory following the naming convention `*.test.ts`:

```typescript
import { someFunction } from '../src/path/to/module';

describe('Module name or functionality', () => {
  test('should do something specific', () => {
    // Arrange
    const input = 'test input';
    
    // Act
    const result = someFunction(input);
    
    // Assert
    expect(result).toBe('expected output');
  });
});
```

## Environment-Specific Testing

### Cross-Environment Testing Approaches

| Environment | Testing Approach | Email Handling | Best For |
|-------------|-----------------|---------------|----------|
| Development | Manual + auto-verify | MailHog (localhost:8025) | Interactive development |
| Test/CI | Jest + mailhog-tests | MailHog (isolated) | Automated verification |
| Staging | End-to-end tests | Real email (test accounts) | Pre-production validation |
| Production | Monitoring | Real email (actual users) | Live system verification |

### Special Testing Scenarios

#### 1. Testing Without Email Access

If you don't have access to MailHog:

1. Use `auto-verify-tests.ps1` which bypasses email verification
2. The script uses the testing API to directly verify accounts

#### 2. Testing Admin Functionality

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

#### 3. Testing in Docker Containers

When testing in a Docker environment:

```powershell
# Modify the base URL in test scripts if needed
$baseUrl = "http://localhost:3000"  # Default
# or
$baseUrl = "http://host.docker.internal:3000"  # Access from another container

# Run tests inside the Docker container
docker-compose -f docker-compose.dev.yml exec auth-service npm test
```

## Troubleshooting

### Common Issues and Solutions

#### Docker Connection Issues

```powershell
# Restart Docker Desktop
Restart-Service com.docker.service

# Start containers if not running
docker-compose -f docker-compose.dev.yml up -d
```

#### MailHog Not Receiving Emails

1. Verify the application is configured to use MailHog:
   ```
   EMAIL_HOST=localhost
   EMAIL_PORT=1025
   ```

2. Check MailHog logs:
   ```powershell
   docker logs mailhog
   ```

3. Restart MailHog:
   ```powershell
   docker-compose -f docker-compose.dev.yml restart mailhog
   ```

#### MongoDB Connection Issues

```powershell
# Check MongoDB container status
docker ps | findstr mongo

# View MongoDB logs
docker logs mongodb

# Restart MongoDB container
docker-compose -f docker-compose.dev.yml restart mongodb
```

#### Jest Test Failures

```powershell
# Run with verbose output
npm test -- --verbose

# Run specific test
npm test -- -t "test name"

# Check for open handles
npm test -- --detectOpenHandles
```

#### API Test Failures

1. Verify the application is running:
   ```powershell
   curl http://localhost:3000/health
   ```

2. Check application logs:
   ```powershell
   docker logs auth-service
   ```

3. Check for port conflicts:
   ```powershell
   netstat -ano | findstr :3000
   ```

#### PowerShell Execution Policy Issues

If PowerShell blocks script execution:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

#### Line Ending Issues with Scripts

If scripts have wrong line endings:

```powershell
# Convert to Windows line endings
(Get-Content .\tests\auth-api-tests.ps1 -Raw).Replace("`n", "`r`n") | Set-Content .\tests\auth-api-tests.ps1 -Force
```

### Debugging with Detailed Logs

For more detailed debugging information:

```powershell
# Run pipeline with verbose logging
.\tests\test-pipeline.ps1 -Verbose

# Check test results directory
Get-ChildItem .\tests\test-results\
```

## Extending the Test Suite

### Adding New Test Categories

1. Create a new PowerShell script for your test category
2. Add the script to the main pipeline in `test-pipeline.ps1`
3. Update documentation in this file

### Creating Custom Health Checks

To add custom health checks:

1. Create a new PowerShell function in `docker-health-check.ps1`
2. Call the function from the main health check routine
3. Return appropriate success/failure status

### Extending MailHog Tests

You can extend the MailHog testing for additional scenarios:

1. **Testing custom email templates**:
   - Add new test cases that trigger different email types
   - Validate content and formatting of each template

2. **Testing email delivery failures**:
   - Simulate failure scenarios by stopping MailHog during tests
   - Verify application handles email failures gracefully

3. **Load testing email processing**:
   - Generate multiple registrations in parallel
   - Measure system performance under email processing load

## Continuous Integration

### Integrating with CI/CD Systems

The testing pipeline can be integrated with CI/CD systems:

```yaml
# Example GitHub Actions workflow
name: Test Authentication System

on: [push, pull_request]

jobs:
  test:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      - name: Set up Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
      - name: Install dependencies
        run: npm ci
      - name: Set up Docker
        uses: docker/setup-buildx-action@v2
      - name: Start Docker containers
        run: docker-compose -f docker-compose.dev.yml up -d
      - name: Run Windows Testing Pipeline
        run: |
          .\tests\test-pipeline.ps1 -CiMode
        shell: pwsh
      - name: Upload test results
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: tests/test-results/
```

### CI Mode Options

The `-CiMode` flag adjusts settings for CI environments:
- Continues on non-critical errors
- Outputs machine-readable logs
- Sets appropriate exit codes

Example:

```powershell
# Run in CI mode
.\tests\test-pipeline.ps1 -CiMode
```

### Testing-specific Environment Variables

When testing in CI environments, configure these variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `TEST_USER_EMAIL` | Email for test user accounts | `test@example.com` |
| `TEST_USER_PASSWORD` | Password for test users | `TestPassword123!` |
| `BYPASS_EMAIL_VERIFICATION` | Skip email verification in tests | `false` |

## Test Results and Reports

All test results are saved to the `tests/test-results` directory:

- `unit-test-results.txt` - Jest test output
- `api-tests-results.txt` - API test results
- `mailhog-tests-results.txt` - Email testing results
- `pipeline-summary.txt` - Overall testing summary

Example of viewing test results:

```powershell
# Open the summary report
notepad .\tests\test-results\pipeline-summary.txt

# View all test result files
Get-ChildItem .\tests\test-results\ | Select-Object Name, Length, LastWriteTime
```

## Conclusion

This comprehensive testing strategy ensures the authentication system works correctly across different environments. The automated Windows testing pipeline provides a convenient way to execute all tests, while individual scripts offer flexibility for specific testing scenarios.

By following these testing practices, you can confidently make changes to the system knowing that your authentication functionality remains secure and reliable.
