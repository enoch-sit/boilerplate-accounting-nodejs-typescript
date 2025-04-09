# Authentication System PowerShell Testing Framework

This document provides a detailed explanation of the PowerShell testing scripts used in the authentication system test suite. These scripts work together to verify the functionality of the authentication system, from unit tests to API endpoint verification and email delivery testing.

## Overview

The testing framework consists of several PowerShell scripts that can be run individually or orchestrated through the main `test-pipeline.ps1` script. The framework is designed to be flexible and can adapt to different environments, such as whether Docker and MailHog are available.

## Script Files

### 1. test-pipeline.ps1

**Purpose**: Main orchestration script that coordinates the entire testing process.

**Features**:

- Executes all other test scripts in the appropriate order
- Verifies Node.js environment
- Checks Docker container health
- Tests MailHog availability
- Runs Jest unit tests
- Coordinates API testing with or without email verification
- Generates detailed reports and summaries

**Usage**:

```powershell
# Run the complete pipeline
.\test-pipeline.ps1

# Run only unit tests
.\test-pipeline.ps1 -UnitTestsOnly

# Run only API tests
.\test-pipeline.ps1 -ApiTestsOnly

# Skip Docker environment checks
.\test-pipeline.ps1 -SkipDockerChecks

# Run with detailed debugging information
.\test-pipeline.ps1 -Debug

# Run with verbose output
.\test-pipeline.ps1 -Verbose
```

**Workflow**:

1. Checks for Node.js and appropriate version
2. Verifies Docker environment (unless skipped)
3. Tests MailHog availability (if Docker is available)
4. Runs Jest unit tests (unless API-only mode)
5. Executes API tests with either MailHog email verification or direct verification
6. Generates comprehensive summary reports and logs

**Debug Mode**: The new Debug mode added to this script creates extensive logs showing detailed information about each step, API calls, responses, errors, and system information. Logs are stored in the `tests/logs` directory.

### 2. docker-health-check.ps1

**Purpose**: Verifies that all necessary Docker containers are running and healthy.

**Features**:

- Checks if Docker is installed and running
- Verifies the status of required containers:
  - Authentication service container
  - MongoDB container
  - MailHog container (optional)
- Tests container health through HTTP endpoints or TCP connections

**Usage**:

```powershell
# Run standalone
.\docker-health-check.ps1

# Run with verbose output
.\docker-health-check.ps1 -Verbose

# Check containers with a specific prefix
.\docker-health-check.ps1 -ContainerPrefix "auth-"
```

**Containers Checked**:

- `auth-service` (or variants): The authentication API service
- `mongodb` (or variants): The database service
- `mailhog` (or variants): The email testing service (marked as optional)

### 3. mailhog-check.ps1

**Purpose**: Tests the functionality of the MailHog email testing service.

**Features**:

- Verifies that MailHog's API is accessible
- Tests sending an email via SMTP to MailHog
- Verifies email receipt through MailHog's API
- Tests email deletion functionality

**Usage**:

```powershell
# Run standalone
.\mailhog-check.ps1

# Run with verbose output
.\mailhog-check.ps1 -Verbose

# Specify custom ports
.\mailhog-check.ps1 -SmtpPort 1025 -ApiPort 8025
```

**Testing Flow**:

1. Checks if MailHog API is accessible
2. Clears any existing messages
3. Sends a test email via SMTP
4. Verifies the test email is received
5. Tests deleting messages

### 4. mailhog-email-tests.ps1

**Purpose**: Tests the complete email functionality of the authentication system using MailHog.

**Features**:

- Tests registration email verification flow
- Tests password reset flow
- Verifies email content and links
- Verifies the complete authentication workflow with email verification

**Usage**:

```powershell
# Run standalone
.\mailhog-email-tests.ps1

# Run with verbose output
.\mailhog-email-tests.ps1 -Verbose

# Specify custom API base URL
.\mailhog-email-tests.ps1 -ApiBaseUrl "http://localhost:4000"
```

**Key Functions**:

- `Clear-MailHogEmails`: Clears all emails in MailHog
- `Wait-ForEmail`: Waits for an email with specific content to arrive
- `Get-VerificationTokenFromEmail`: Extracts verification token from email body
- `Register-NewUser`: Creates a new user and triggers verification email
- `Verify-Email`: Verifies an email using a token
- `Request-PasswordReset`: Requests a password reset email
- `Reset-Password`: Resets a password using a token

### 5. auto-verify-tests.ps1

**Purpose**: Tests the authentication API without relying on email verification, using direct verification endpoints.

**Features**:

- Tests complete authentication flow without MailHog
- Directly retrieves verification and reset tokens from testing endpoints
- Tests user registration, login, token refresh, and protected routes
- Generates detailed HTML test reports

**Usage**:

```powershell
# Run standalone
.\auto-verify-tests.ps1

# Run with verbose output
.\auto-verify-tests.ps1 -Verbose

# Specify custom API base URL
.\auto-verify-tests.ps1 -BaseUrl "http://localhost:4000"
```

**Testing Flow**:

1. Tests health endpoint
2. Registers a new user
3. Retrieves verification token directly via testing API
4. Verifies email with token
5. Tests login with verified account
6. Tests accessing protected routes
7. Tests token refresh
8. Tests password reset flow
9. Tests logout functionality

### 6. auth-api-tests.ps1

**Purpose**: Tests all authentication API endpoints directly, without complex flows.

**Features**:

- Tests individual API endpoints
- Tests auth routes (signup, login, refresh, logout)
- Tests protected routes (profile, settings)
- Tests admin routes with appropriate permissions
- Saves API responses for reference

**Usage**:

```powershell
# Run standalone
.\auth-api-tests.ps1
```

**Testing Flow**:

1. Tests signup endpoint
2. Tests login endpoint
3. Tests token refresh
4. Tests forgot password functionality
5. Tests password reset
6. Tests protected routes with authentication
7. Tests admin routes with authentication
8. Tests logout and token invalidation

## Logs and Results

The updated testing framework now generates extensive logs and results:

- **Logs Directory**: `tests/logs/`
  - Contains detailed log files with timestamps for each test run
  - Includes extended debug information when running with `-Debug`

- **Test Results Directory**: `tests/test-results/`
  - `unit-test-results.txt`: Raw output from Jest unit tests
  - `api-tests-results.txt`: Output from API endpoint tests
  - `mailhog-tests-results.txt`: Output from email verification tests
  - `auto-verify-results.txt`: Output from automated verification tests
  - `pipeline-summary.txt`: Human-readable summary of all tests
  - `pipeline-summary.json`: Machine-readable JSON summary for integrations
  - Various JSON reports with detailed test results

## Using Debug Mode

The new Debug mode (`-Debug` parameter) provides extensive logging that can help diagnose issues in the testing pipeline or authentication system:

```powershell
.\test-pipeline.ps1 -Debug
```

Debug mode provides:

- Detailed system information
- Step-by-step execution logs
- API request and response details
- Timing information for each operation
- Error stack traces and details
- Container health details
- Test execution details with exit codes

## Troubleshooting Common Issues

### Docker Containers Not Available

- Check that Docker is running: `docker version`
- Check container status: `docker ps`
- Start required containers using Docker Compose if needed

### MailHog Not Working

- Verify MailHog container is running: `docker ps | findstr mailhog`
- Check port conflicts: `netstat -ano | findstr :8025`
- Test SMTP port: `Test-NetConnection -ComputerName localhost -Port 1025`

### Unit Tests Failing

- Check test details in `unit-test-results.txt`
- Run tests directly: `npm test -- --verbose`
- Check for code issues in failing tests

### API Tests Failing

- Check if API service is running: `curl http://localhost:3000/health`
- Check API logs: `docker logs auth-service`
- Look for error messages in `api-tests-results.txt`

## Integration with CI/CD

The testing framework supports continuous integration through the `-CiMode` parameter, which adjusts error handling for automated environments:

```powershell
.\test-pipeline.ps1 -CiMode
```

The exit code from the script (0 for success, 1 for failure) can be used by CI/CD systems to determine if the build passed or failed.

## Extending the Framework

To add new tests:

1. Create a new PowerShell script in the `tests` directory
2. Follow the patterns in existing scripts (parameters, error handling, etc.)
3. Update the main `test-pipeline.ps1` to include your new script
4. Update this documentation to reflect the new script's purpose and usage
