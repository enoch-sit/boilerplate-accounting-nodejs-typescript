# Windows Development and Testing Pipeline

This document outlines the comprehensive testing pipeline for Windows development environments, providing a systematic approach to verify all aspects of the authentication system.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Pipeline Components](#pipeline-components)
4. [Running the Pipeline](#running-the-pipeline)
5. [Unit Testing](#unit-testing)
6. [Docker Environment Verification](#docker-environment-verification)
7. [MailHog Testing](#mailhog-testing)
8. [API Endpoint Testing](#api-endpoint-testing)
9. [Automated Email Verification Testing](#automated-email-verification-testing)
10. [Troubleshooting](#troubleshooting)
11. [Extending the Pipeline](#extending-the-pipeline)

## Overview

The Windows testing pipeline is designed to provide a consistent, reliable way to verify all aspects of the authentication system, from unit tests to end-to-end API testing. It includes checks for Docker environment health, MailHog functionality, and fallback options when certain components are unavailable.

## Prerequisites

- Windows 10/11
- PowerShell 5.1 or later
- Node.js v18+ and npm
- Docker Desktop for Windows
- MongoDB (local or containerized)
- Git for Windows

## Pipeline Components

The testing pipeline consists of several key components:

1. **test-pipeline.ps1** - Main orchestrator script that runs all tests in sequence
2. **docker-health-check.ps1** - Verifies Docker containers are running correctly
3. **mailhog-check.ps1** - Tests MailHog functionality
4. **Jest Unit Tests** - Validates core logic
5. **API Testing Scripts** - Verifies API endpoints

## Running the Pipeline

To run the complete testing pipeline:

```powershell
# Navigate to project directory
cd c:\path\to\simple-accounting

# Start the pipeline
.\tests\test-pipeline.ps1
```

For specific test categories:

```powershell
# Run only unit tests
.\tests\test-pipeline.ps1 -UnitTestsOnly

# Run only API tests
.\tests\test-pipeline.ps1 -ApiTestsOnly

# Run with extended logging
.\tests\test-pipeline.ps1 -Verbose
```

## Unit Testing

Unit tests verify the core functionality of individual components without external dependencies.

### Running Unit Tests

```powershell
npm test
```

This will run all Jest tests defined in the project.

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

## Docker Environment Verification

The pipeline automatically checks that all required Docker containers are running and healthy.

### Manual Docker Verification

```powershell
# Verify all containers are running
docker ps

# Check specific container logs
docker logs mongodb
docker logs mailhog

# Restart containers if needed
docker-compose -f docker-compose.dev.yml restart auth-service
```

### Docker Health Check Script

The `docker-health-check.ps1` script verifies:

1. Docker Desktop is running
2. Required containers are up (MongoDB, MailHog, etc.)
3. Containers are responding correctly on their ports

If any checks fail, the script will attempt to restart the relevant containers.

## MailHog Testing

MailHog testing verifies that emails are properly sent and can be retrieved through the MailHog API.

### Manual MailHog Verification

1. Access the MailHog UI at http://localhost:8025
2. Send a test email via the application
3. Verify the email appears in the UI

### MailHog API Testing

The `mailhog-check.ps1` script performs:

1. Connection test to MailHog API
2. Test email sending
3. Email retrieval verification

Example MailHog API interaction:

```powershell
# Get all messages
Invoke-RestMethod -Uri "http://localhost:8025/api/v2/messages"

# Delete all messages
Invoke-RestMethod -Uri "http://localhost:8025/api/v1/messages" -Method Delete
```

## API Endpoint Testing

The pipeline tests all API endpoints with both MailHog-dependent and independent approaches.

### Testing with MailHog

When MailHog is available, the full email verification flow is tested:

```powershell
# Run email verification tests with MailHog
.\tests\mailhog-email-tests.ps1
```

### Testing without MailHog

If MailHog is unavailable, the pipeline falls back to direct verification:

```powershell
# Run tests with direct verification bypass
.\tests\auto-verify-tests.ps1
```

### Testing Specific Endpoints

For testing individual endpoints:

```powershell
# Test registration endpoint
$body = @{
  username = "testuser123"
  email = "test@example.com"
  password = "TestPassword123!"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:3000/api/auth/signup" -Method Post -ContentType "application/json" -Body $body
```

## Automated Email Verification Testing

The pipeline includes two approaches for testing email verification:

1. **MailHog-based** - Extracts verification tokens from emails captured in MailHog
2. **Direct API** - Uses the testing API to directly verify accounts

### Direct Verification API

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

## Troubleshooting

### Common Issues and Solutions

#### Docker Connection Issues

```powershell
# Restart Docker Desktop
Restart-Service com.docker.service
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

#### Jest Test Failures

```powershell
# Run with verbose output
npm test -- --verbose

# Run specific test
npm test -- -t "test name"
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

## Extending the Pipeline

### Adding New Test Categories

1. Create a new PowerShell script for your test category
2. Add the script to the main pipeline in `test-pipeline.ps1`
3. Update documentation in this file

### Integrating with CI/CD

The pipeline can be integrated with CI/CD systems like GitHub Actions or Azure DevOps:

```yaml
# Example GitHub Actions workflow step
- name: Run Windows Testing Pipeline
  run: |
    .\tests\test-pipeline.ps1 -CiMode
  shell: pwsh
```

### Creating Custom Health Checks

To add custom health checks:

1. Create a new PowerShell function in `docker-health-check.ps1`
2. Call the function from the main health check routine
3. Return appropriate success/failure status