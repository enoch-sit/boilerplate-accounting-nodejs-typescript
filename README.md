# Simple Authentication and Accounting System with TypeScript and MongoDB using JWT

A robust authentication system built with TypeScript, Express, and MongoDB. Features include user registration, email verification, JWT authentication, password reset, and protected routes.

## Features

- **User Registration**: Secure signup with email verification
- **JWT Authentication**: Access and refresh tokens with expiration
- **Email Integration**: Verification emails and password reset functionality
- **Protected Routes**: Middleware for authenticated endpoints
- **Password Management**: Secure hashing and reset functionality
- **Database Integration**: MongoDB for data persistence
- **Role-Based Access Control**: Admin, Supervisor, and User roles with appropriate permissions

## API Endpoints

### Auth Routes (`/api/auth`)

| Endpoint                       | Method | Description                           | Access Level      |
|--------------------------------|--------|---------------------------------------|-------------------|
| `/api/auth/signup`             | POST   | Register a new user                   | Public            |
| `/api/auth/verify-email`       | POST   | Verify email with token               | Public            |
| `/api/auth/resend-verification`| POST   | Resend verification code              | Public            |
| `/api/auth/login`              | POST   | Login with credentials                | Public            |
| `/api/auth/refresh`            | POST   | Refresh access token                  | Public            |
| `/api/auth/logout`             | POST   | Logout (invalidate token)             | Public            |
| `/api/auth/logout-all`         | POST   | Logout from all devices               | Authenticated     |
| `/api/auth/forgot-password`    | POST   | Request password reset                | Public            |
| `/api/auth/reset-password`     | POST   | Reset password with token             | Public            |

### Protected Routes (`/api/protected`)

| Endpoint                       | Method | Description                           | Access Level      |
|--------------------------------|--------|---------------------------------------|-------------------|
| `/api/protected/profile`       | GET    | Get user profile                      | Authenticated     |
| `/api/protected/profile`       | PUT    | Update user profile                   | Authenticated     |
| `/api/protected/change-password`| POST   | Change password                       | Authenticated     |
| `/api/protected/dashboard`     | GET    | Access protected dashboard content    | Authenticated     |

### Admin Routes (`/api/admin`)

| Endpoint                       | Method | Description                           | Access Level      |
|--------------------------------|--------|---------------------------------------|-------------------|
| `/api/admin/users`             | GET    | Get all users                         | Admin             |
| `/api/admin/users/:userId/role`| PUT    | Update user role                      | Admin             |
| `/api/admin/reports`           | GET    | Access reports                        | Admin/Supervisor  |
| `/api/admin/dashboard`         | GET    | Access dashboard                      | Any Authenticated |

### Testing Routes (`/api/testing`) - Development Only

| Endpoint                                | Method | Description                           | Access Level      |
|-----------------------------------------|--------|---------------------------------------|-------------------|
| `/api/testing/verification-token/:userId/:type?` | GET  | Get verification token for a user     | Development       |
| `/api/testing/verify-user/:userId`      | POST   | Directly verify a user without token  | Development       |

### Miscellaneous Endpoints

| Endpoint                       | Method | Description                           | Access Level      |
|--------------------------------|--------|---------------------------------------|-------------------|
| `/health`                      | GET    | Health check endpoint                 | Public            |

## Testing

This project includes comprehensive testing capabilities, from automated unit tests to API integration tests using both PowerShell and bash scripts.

### Testing Components

The project includes several testing tools:

| Test File | Purpose | Usage Scenario |
|-----------|---------|----------------|
| `tests/auth.test.ts` | Jest unit tests for core authentication logic | Continuous integration, code quality |
| `tests/auth-api-tests.ps1` | PowerShell script for testing all API endpoints | Windows development, comprehensive API testing |
| `tests/auth-api-curl-tests.sh` | Bash/curl script for testing all API endpoints | Linux/macOS/Git Bash, individual endpoint testing |
| `tests/auto-verify-tests.ps1` | PowerShell script with automated email verification | Windows testing without email client access |

### Running Automated Tests

```bash
# Run Jest unit tests
npm test

# Run PowerShell API tests (Windows)
.\tests\auth-api-tests.ps1

# Run automated email verification tests (Windows)
.\tests\auto-verify-tests.ps1

# Run bash/curl API tests (Git Bash on Windows or Linux/macOS)
bash ./tests/auth-api-curl-tests.sh
```

### Testing in a Docker Windows Environment

When testing in a Docker environment on Windows, there are a few special considerations:

#### 1. Container Network Access

When running the service in Docker and tests on your host Windows machine:

```powershell
# Modify the base URL in your test scripts if needed
$baseUrl = "http://localhost:3000"  # Default
# or
$baseUrl = "http://host.docker.internal:3000"  # Access from another container
```

#### 2. Automated Email Verification

The `auto-verify-tests.ps1` script contains special features for testing in a development environment:

- Automatically fetches verification tokens from the database
- Directly verifies user accounts without requiring email access
- Tests the full authentication flow from registration to protected route access

This is especially useful in Docker environments where accessing the email service might be difficult.

#### 3. Testing Routes

The project includes special testing routes (only enabled in development):

```
/api/testing/verification-token/:userId    - Get verification token for a user
/api/testing/verify-user/:userId           - Directly verify a user without token
```

These routes make automated testing much easier in containerized environments by bypassing email verification.

#### 4. Running Tests Inside Docker

You can also run the tests directly within the Docker environment:

```bash
# Run tests inside the Docker container
docker-compose -f docker-compose.dev.yml exec auth-service npm test

# Or for a one-off test run
docker-compose -f docker-compose.dev.yml run --rm auth-service npm test
```

### Testing Workflow

Here's a recommended testing workflow:

1. **Development Testing**:
   - Use `auto-verify-tests.ps1` during development to quickly test the authentication flow
   - This script handles registration, email verification, login, and protected route access

2. **Comprehensive API Testing**:
   - Use `auth-api-tests.ps1` (Windows) or `auth-api-curl-tests.sh` (Bash) to test all endpoints
   - These scripts test every API endpoint and save responses for inspection

3. **CI/CD Pipeline**:
   - Use Jest tests (`auth.test.ts`) in your continuous integration pipeline
   - These provide automated verification of core authentication functionality

4. **Manual Testing**:
   - The test scripts generate detailed logs and save API responses to `tests/curl-tests/` 
   - Review these files to understand the API behavior

### Email Verification Testing Options

The project provides three ways to test email verification:

1. **Real Email** (Production):
   - Actual emails sent to real addresses
   - User clicks link in email to verify

2. **MailHog** (Development & Testing):
   - Emails captured by MailHog service
   - Access via web UI at http://localhost:8025 (development) or http://localhost:8026 (testing)
   - Automated testing through MailHog API
   - Complete email verification workflow testing without real email services

3. **Automated Verification** (Testing):
   - `auto-verify-tests.ps1` script bypasses email
   - Direct database verification via testing API

### MailHog Testing Pipeline

This project includes a dedicated MailHog testing pipeline for comprehensive email verification testing.

#### Why Use MailHog Testing?

- Tests actual email delivery without sending real emails
- Validates the complete email verification cycle
- Automates testing of verification token extraction from emails
- Creates a realistic test environment for email-dependent features
- Ensures email templates are rendering correctly

#### When to Use Which Email Testing Approach:

| Approach | Best For | When To Use |
|----------|----------|-------------|
| **Real Email** | Production validation | Final pre-deployment testing; user acceptance testing |
| **MailHog Testing** | Email flow verification | Testing email templates; verification flow; password reset flow |
| **Automated Verification** | Rapid API testing | Quick development cycles; CI/CD pipelines; when email content isn't the focus |

#### MailHog Testing Components

| Component | Purpose |
|-----------|---------|
| `docker-compose.mailhog-test.yml` | Isolated Docker environment for email testing |
| `tests/mailhog-email-tests.ps1` | PowerShell script for testing email verification flow with MailHog |
| `tests/email.test.ts` | Jest tests specifically for email verification with MailHog |

#### Running MailHog Tests

```bash
# Start the MailHog test environment
docker-compose -f docker-compose.mailhog-test.yml up -d

# Run PowerShell MailHog tests
npm run mailhog:test

# Run Jest email tests
npm run test:mailhog
```

#### Accessing MailHog

- Development environment: http://localhost:8025
- Test environment: http://localhost:8026

The web interface allows you to:
- View all captured emails
- Inspect email content (HTML and text)
- Check headers and recipients
- Validate email templates visually

### Testing-specific Environment Variables

When testing, you can configure these environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `TEST_USER_EMAIL` | Email for test user accounts | `test@example.com` |
| `TEST_USER_PASSWORD` | Password for test users | `TestPassword123!` |
| `BYPASS_EMAIL_VERIFICATION` | Skip email verification in tests | `false` |

### Troubleshooting Tests in Docker Windows Environment

Common issues and solutions when testing in Docker on Windows:

1. **Connection Refused Errors**:
   - Ensure your Docker containers are running: `docker ps`
   - Check that port mapping is correct: `-p 3000:3000`
   - Try using `host.docker.internal` instead of `localhost` in test scripts

2. **MongoDB Connection Issues**:
   - Verify MongoDB container is running: `docker ps | findstr mongo`
   - Check MongoDB logs: `docker logs mongodb`
   - Ensure connection string is correct in your .env files

3. **Email Verification Failures**:
   - If using MailHog, verify it's running: `docker ps | findstr mailhog`
   - Check MailHog web UI: http://localhost:8025
   - Use the `auto-verify-tests.ps1` script to bypass email verification

4. **PowerShell Execution Policy**:
   - If PowerShell blocks script execution, run:
     ```powershell
     Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
     ```
   - Then run your test script

5. **File Permission Issues**:
   - Ensure Docker volume mounts have proper permissions
   - If test output files can't be written, check your user permissions

By using these testing tools and strategies, you can thoroughly validate your authentication system's functionality across different environments, including Docker on Windows.

### Setting Up MongoDB on Windows

1. **Download and Install MongoDB**:
   - Visit the MongoDB download page and download the latest version for Windows.
   - Follow the installation instructions to install MongoDB Community Server.

2. **Start MongoDB Service**:
   - Open Command Prompt as Administrator.
   - Navigate to the MongoDB bin directory (e.g., `C:\Program Files\MongoDB\Server\6.0\bin`).
   - `mkdir C:\data\db`
   - `mkdir C:\data\log`
   - Run `mongod --dbpath C:\data\db` to start the MongoDB server.

3. **Test Connection**:
   - Open another Command Prompt.
   - Run `mongosh` to connect to the MongoDB shell. not `mongo`
   - Use `show dbs` to list databases and confirm the connection.

### Setting Up MongoDB on Linux

1. **Install MongoDB**:
   - For Ubuntu/Debian:

     ```bash
     sudo apt-get install -y mongodb-org
     ```

   - For CentOS/RHEL:

     ```bash
     sudo yum install -y mongodb-org
     ```

2. **Start MongoDB Service**:
   - Start the service with:

     ```bash
     sudo systemctl start mongod
     ```

   - Enable MongoDB to start on boot:

     ```bash
     sudo systemctl enable mongod
     ```

3. **Test Connection**:
   - Connect to MongoDB with:

     ```bash
     mongo
     ```

   - Use `show dbs` to list databases and confirm the connection.

### Setting Up MongoDB on AWS

1. **Create an Amazon DocumentDB Cluster**:
   - Navigate to the AWS Management Console.
   - Go to the Amazon DocumentDB service.
   - Create a new cluster, choosing instance type and other settings as needed.

2. **Connect to DocumentDB**:
   - Use the AWS CLI or SDK to connect to your DocumentDB cluster.
   - Example connection string:

     ```bash
     mongodb://username:password@docdb-2025-03-27.cluster-c123456789abcdef0.c123456789abcdef0.docdb.amazonaws.com:27017/?ssl=true&ssl_ca_certs=rds-combined-ca-bundle.pem
     ```

3. **Test Connection**:
   - Use a MongoDB client or the `mongo` shell to connect to your DocumentDB instance.
   - Use `show dbs` to list databases and confirm the connection.

- **Environment Configuration**: Separate settings for development and production

## Technologies

- **Backend**: Node.js, Express
- **Language**: TypeScript
- **Database**: MongoDB, Mongoose
- **Authentication**: JSON Web Tokens (JWT)
- **Email**: Nodemailer (MailHog for development, AWS SES for production)
- **Security**: Helmet, rate limiting, CORS
- **Logging**: Winston

## Quick Start

### Prerequisites

• Node.js (v18+)
• MongoDB (Local or Atlas)
• npm

### Installation

1. **Clone the repository**:

   ```bash
   git clone https://github.com/enoch-sit/boilerplate-auth-simple-nodejs-typescript.git
   cd boilerplate-auth-simple-nodejs-typescript
   ```

2. **Install dependencies**:

   ```bash
   npm install
   ```

3. **Set up environment variables**:
   • Create `.env.development` and `.env.production` files in the root directory.
   • Use the templates provided in the project documentation.

4. **Start the development server**:

   ```bash
   npm run dev
   ```

## Configuration

### Environment Variables

| Variable                | Description                          | Example                   |
|-------------------------|--------------------------------------|---------------------------|
| `MONGO_URI`             | MongoDB connection string            | `mongodb://localhost:27017/auth` |
| `JWT_ACCESS_SECRET`     | Secret key for access tokens         | `your_access_secret`      |
| `JWT_REFRESH_SECRET`    | Secret key for refresh tokens        | `your_refresh_secret`     |
| `EMAIL_HOST`            | SMTP server host                     | `smtp.mailservice.com`    |
| `EMAIL_PORT`            | SMTP server port                     | `587`                     |
| `EMAIL_USER`            | SMTP username                        | `user@example.com`        |
| `EMAIL_PASS`            | SMTP password                        | `password123`            |

### Email Setup

• **Development**: Use MailHog (included in Docker setup)

  ```bash
  docker run -d -p 1025:1025 -p 8025:8025 mailhog/mailhog
  ```

• **Production**: Configure AWS SES or another SMTP service.

## Deployment

### Production Considerations

1. **Database**: Use MongoDB Atlas for a managed MongoDB service.
2. **Email**: Configure AWS SES in `.env.production`.
3. **HTTPS**: Use a reverse proxy (Nginx) or cloud provider (AWS, Heroku).
4. **Environment Variables**: Store secrets securely (e.g., AWS Secrets Manager).

### Docker

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build
CMD ["npm", "start"]
```

## Docker Setup

This project includes Docker configuration for both development/testing and production environments, making it easy to set up and run consistently across different systems.

### Using Docker for Development and Testing

The development environment uses `Dockerfile.dev` and `docker-compose.dev.yml` to create a complete testing environment with hot-reloading.

#### Prerequisites

- Docker and Docker Compose installed on your system
- Git for cloning the repository

#### Step 1: Start the Development Environment

```bash
# Start the development environment with hot-reloading
docker-compose -f docker-compose.dev.yml up auth-service
```

This command:
- Builds a Docker image using the Dockerfile.dev configuration
- Starts a MongoDB container for local development
- Runs the application with ts-node-dev for hot-reloading
- Maps port 3000 to your host machine
- Mounts your code as a volume for real-time changes

#### Step 2: Running Tests

```bash
# Run the entire test suite
docker-compose -f docker-compose.dev.yml up auth-test
```

To run specific tests or with specific options:

```bash
# Run a specific test or with specific Jest options
docker-compose -f docker-compose.dev.yml run --rm auth-test npm test -- -t "specific test name"
```

#### Step 3: Stopping the Environment

```bash
# Stop all containers when finished
docker-compose -f docker-compose.dev.yml down

# To remove volumes (database data) as well
docker-compose -f docker-compose.dev.yml down -v
```

### Using Docker for Production

The production environment uses the `Dockerfile` which creates an optimized, smaller image suitable for deployment.

#### Step 1: Build the Production Image

```bash
# Build the production Docker image
docker build -t auth-service-prod .
```

#### Step 2: Run the Production Container

```bash
# Run the container with production settings
docker run -p 3000:3000 \
  -e MONGO_URI=mongodb://your-mongo-instance:27017/auth \
  -e JWT_SECRET=your_production_secret \
  -e NODE_ENV=production \
  auth-service-prod
```

Replace the environment variables with your actual production values.

#### Step 3: Deploy to Cloud Services (Optional)

For AWS deployment:

1. Push your Docker image to Amazon ECR:
   ```bash
   aws ecr get-login-password --region region | docker login --username AWS --password-stdin aws_account_id.dkr.ecr.region.amazonaws.com
   docker tag auth-service-prod:latest aws_account_id.dkr.ecr.region.amazonaws.com/auth-service:latest
   docker push aws_account_id.dkr.ecr.region.amazonaws.com/auth-service:latest
   ```

2. Deploy using ECS or EKS with the appropriate task definitions or Kubernetes manifests.

### Docker Configuration Files

#### Dockerfile.dev (Development)

This Dockerfile is optimized for development:
- Includes all dependencies (including devDependencies)
- Doesn't pre-compile TypeScript for faster iterations
- Mounts your code as a volume for hot-reloading

#### Dockerfile (Production)

This Dockerfile is optimized for production:
- Uses a multi-stage build for a smaller image
- Only includes production dependencies
- Pre-compiles TypeScript code
- Sets NODE_ENV to production

#### docker-compose.dev.yml

This Docker Compose file sets up a complete development environment:
- auth-service: The main application in development mode
- auth-test: A service configured to run tests
- mongodb: A MongoDB instance for local development

### Troubleshooting Docker Setup

If you encounter issues with the Docker setup:

1. **Connection errors to MongoDB**:
   - Make sure the MongoDB container is running: `docker ps`
   - Check the MongoDB logs: `docker-compose -f docker-compose.dev.yml logs mongodb`

2. **Hot-reloading not working**:
   - Ensure volume mounts are correct in docker-compose.dev.yml
   - Check that ts-node-dev is running correctly: `docker-compose -f docker-compose.dev.yml logs auth-service`

3. **Test failures**:
   - Check if MongoDB is available to the test container
   - Use `docker-compose -f docker-compose.dev.yml run --rm auth-test npm test -- --verbose` for more detailed output

## License

MIT License. See `LICENSE` for details.

## Testing Pipeline

The project includes a comprehensive Windows-based development and testing pipeline that enables streamlined verification of all system components.

### Key Features

- **Unified Test Command**: Run the complete test suite with a single command
- **Environment Validation**: Automatically verifies Docker services and MailHog are running
- **Email Testing**: Tests both with and without MailHog email verification
- **Fallback Mechanisms**: Uses direct verification when MailHog isn't available
- **Detailed Reporting**: Generates comprehensive test reports

### Quick Start

```powershell
# Run the complete testing pipeline
.\tests\test-pipeline.ps1

# Run only unit tests
.\tests\test-pipeline.ps1 -UnitTestsOnly

# Run only API endpoint tests
.\tests\test-pipeline.ps1 -ApiTestsOnly
```

For detailed information about the testing pipeline, see [Test Documentation](./tests/Test.md).

## Windows Development and Testing Pipeline

This project includes a comprehensive Windows development and testing pipeline to ensure the authentication system functions correctly across various environments.

### Quick Start for Windows Testing

```powershell
# Run the complete testing pipeline
.\tests\test-pipeline.ps1

# Run only unit tests
.\tests\test-pipeline.ps1 -UnitTestsOnly

# Run only API tests
.\tests\test-pipeline.ps1 -ApiTestsOnly
```

The pipeline automatically adapts to your environment:

1. **Complete Environment**: Tests everything including email verification with MailHog
2. **Minimal Environment**: Falls back to direct verification if MailHog is unavailable
3. **Local Development**: Can run tests that don't require Docker services

For detailed instructions and troubleshooting, see [Test.md](./tests/Test.md).

### Pipeline Features

- **Unit Testing**: Core functionality validation with Jest
- **Docker Environment Checks**: Verifies containers are running properly
- **MailHog Testing**: Validates email testing infrastructure
- **API Endpoint Testing**: Tests all endpoints with comprehensive coverage
- **Adaptive Testing**: Continues testing when some services are unavailable
- **Detailed Reporting**: Generates reports of all test results

### Troubleshooting Common Issues

```powershell
# Check Docker containers health
.\tests\docker-health-check.ps1

# Test MailHog functionality
.\tests\mailhog-check.ps1

# Run API tests with email verification bypass
.\tests\auto-verify-tests.ps1
```
````
