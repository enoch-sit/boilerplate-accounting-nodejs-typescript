# Python Testing Tools for Authentication System

This directory contains Python-based testing tools for the authentication system Docker containers. These tools provide an alternative to the PowerShell-based testing scripts found in the `/tests` directory, particularly useful for cross-platform testing or when PowerShell is not available.

## Table of Contents

1. [Overview](#overview)
2. [Available Tools](#available-tools)
3. [Installation](#installation)
4. [Usage Examples](#usage-examples)
5. [Configuration](#configuration)
6. [Logging](#logging)
7. [Extending](#extending)

## Overview

These Python testing tools provide automated testing capabilities for the authentication system's Docker containers. They focus on:

- Testing API endpoints in the authentication service
- Scanning and testing MailHog service
- Verifying email delivery functionality
- Detecting and validating Docker container configurations

The tools are designed to work with both development and testing environments as defined in the project's Docker Compose files.

## Available Tools

### docker_test.py

A comprehensive test suite for the authentication system's Docker containers. It implements the same testing flow described in `DockerManuelCurlTest.md` but with automated execution and validation.

**Features:**
- Health checks for authentication service
- Complete user lifecycle testing (registration, verification, login, password reset, logout)
- Protected route access testing
- Automatic MailHog detection and configuration
- Detailed logging to `pyTest.log`

### mailhog_scanner.py

A specialized tool for scanning and detecting MailHog instances running on the local machine. It identifies SMTP and API ports, determines API versions, and validates functionality.

**Features:**
- Port scanning to detect MailHog instances
- SMTP protocol detection
- API endpoint validation (v1 and v2 API)
- Functionality testing via email sending and retrieval
- Comprehensive logging of detected configurations

### test.py

A basic test runner that provides foundational support for other testing scripts.

## Installation

### Requirements

```
pip install requests colorama python-dotenv
```

## Usage Examples

### Testing Docker Containers

```powershell
# Run tests against the development environment
python pyTesting/docker_test.py --env dev

# Run tests against the MailHog test environment
python pyTesting/docker_test.py --env mailhog

# Run tests with automatic MailHog port scanning
python pyTesting/docker_test.py --env dev --scan-ports
```

### Scanning for MailHog Instances

```powershell
# Scan for MailHog instances with default port range (1024-10000)
python pyTesting/mailhog_scanner.py

# Scan with custom port range
python pyTesting/mailhog_scanner.py --port-range 1024 9000

# Scan on a different host
python pyTesting/mailhog_scanner.py --host docker.local
```

## Configuration

The test scripts are pre-configured to work with the standard Docker Compose environments:

1. **Development Environment** (`docker-compose.dev.yml`):
   - Auth Service: http://localhost:3000
   - MongoDB: localhost:27018
   - MailHog: http://localhost:8025 (UI) / localhost:1025 (SMTP)

2. **MailHog Test Environment** (`docker-compose.mailhog-test.yml`):
   - Auth Service: http://localhost:3001
   - MongoDB: localhost:27018
   - MailHog: http://localhost:8026 (UI) / localhost:1026 (SMTP)

## Logging

All test results are logged to `pyTest.log` in the project root directory. The log includes:

- Test execution timestamps
- Environment information
- API requests and responses
- MailHog configuration details
- Test results and error messages

Example log entry:
```
2025-04-09 15:30:00 [INFO] Docker Testing started at 2025-04-09 15:30:00
2025-04-09 15:30:00 [INFO] Environment: dev
2025-04-09 15:30:00 [INFO] Auth URL: http://localhost:3000
2025-04-09 15:30:00 [INFO] Testing health endpoint
2025-04-09 15:30:01 [INFO] Health check successful: 200
```

## Extending

### Adding New Tests

To add a new test to `docker_test.py`:

1. Add a new method to the `DockerApiTests` class
2. Name it with the `test_` prefix followed by a number for execution order
3. Include a descriptive docstring
4. Log test activities with `logging.info()`
5. Use assertions to validate expected behavior

Example:

```python
def test_18_custom_feature(self):
    """Test a custom feature of the authentication system."""
    print(f"\n{Fore.CYAN}=== Testing Custom Feature ==={Style.RESET_ALL}")
    logging.info("Testing custom feature")
    
    try:
        response = requests.get(f"{self.auth_url}/api/custom-feature")
        response.raise_for_status()
        data = response.json()
        
        self.assertEqual(response.status_code, 200)
        self.assertTrue('feature' in data)
        print(f"{Fore.GREEN}Custom feature test successful{Style.RESET_ALL}")
        logging.info("Custom feature test successful")
    except RequestException as e:
        logging.error(f"Custom feature test failed: {e}")
        self.fail(f"Custom feature test failed: {e}")
```

### Adding New Scanner Features

To extend the `mailhog_scanner.py` script:

1. Add new detection methods for additional protocols or services
2. Add test functions for specific features
3. Update the main detection logic to incorporate your new methods
4. Log results consistently using the established logging system