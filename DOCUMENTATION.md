# Simple Authentication and Accounting System

## Comprehensive Documentation for Beginners

This documentation provides a detailed guide to help beginners understand, set up, and use the Simple Authentication and Accounting System. This system is built with TypeScript, Express, and MongoDB, featuring JWT authentication and role-based access control.

## Table of Contents

1. [System Overview](#system-overview)
2. [Features](#features)
3. [Architecture](#architecture)
4. [Installation and Setup](#installation-and-setup)
5. [Running the Application](#running-the-application)
6. [API Endpoints](#api-endpoints)
7. [Authentication Flow](#authentication-flow)
8. [Role-Based Access Control](#role-based-access-control)
9. [Email Configuration](#email-configuration)
10. [Testing](#testing)
11. [Troubleshooting](#troubleshooting)
12. [Advanced Configurations](#advanced-configurations)
13. [Production Deployment](#production-deployment)
14. [AWS Deployment](#aws-deployment)

---

## System Overview

The Simple Authentication and Accounting System is a robust backend solution for handling user authentication, authorization, and account management. It provides a solid foundation for building secure web applications with features like user registration, email verification, password reset, and role-based access control.

The system is designed to be scalable, secure, and easy to integrate with frontend applications. It follows modern development practices and employs industry-standard security measures to protect user data.

## Features

- **User Registration**: Secure signup with email verification
- **JWT Authentication**: Access and refresh tokens with expiration
- **Email Integration**: Verification emails and password reset functionality
- **Protected Routes**: Middleware for authenticated endpoints
- **Password Management**: Secure hashing and reset functionality
- **Database Integration**: MongoDB for data persistence
- **Role-Based Access Control**: Admin, Supervisor, and User roles with appropriate permissions
- **Docker Support**: Development and production environments with Docker Compose
- **Comprehensive Testing**: Unit tests and deployment validation scripts
- **Security Features**:
  - Secure password hashing with bcrypt
  - Short-lived JWT access tokens with refresh mechanism
  - Rate limiting on authentication endpoints
  - Email verification for new accounts
  - Secure password reset flow
  - HTTP security headers with Helmet
  - CORS protection

## Architecture

The authentication system follows a modern architecture with:

### System Components

- **Express.js Backend**: Handles API requests and implements business logic
- **MongoDB Database**: Stores user data, tokens, and verification records
- **JWT Authentication**: Secure token-based authentication with refresh mechanism
- **Role-Based Access Control**: Hierarchical permission structure
- **Email Service Integration**: For verification and password reset processes

### Database Structure

The system uses MongoDB with three primary collections:

- **Users Collection**: Stores user credentials and profile information
- **Tokens Collection**: Stores refresh tokens for maintaining user sessions
- **Verification Collection**: Supports email verification and password reset

### API Structure

The API is organized into route modules using Express.js:

- **Auth Routes**: Handle user authentication and account management
- **Protected Routes**: Require authentication to access
- **Admin Routes**: Restricted to users with administrative privileges
- **Testing Routes**: Available only in development environment

## Installation and Setup

### Prerequisites

Before you begin, ensure you have installed:

- [Node.js](https://nodejs.org/) (v18+ recommended)
- [npm](https://www.npmjs.com/) or [yarn](https://yarnpkg.com/)
- [Docker](https://www.docker.com/get-started) and Docker Compose (recommended)
- [MongoDB](https://www.mongodb.com/try/download/community) (if not using Docker)

### Option 1: Setup with Docker (Recommended for Beginners)

Docker provides the easiest way to get started, as it handles all dependencies and configurations automatically.

1. **Clone the repository**:

   ```bash
   git clone https://github.com/yourusername/simple-auth-accounting.git
   cd simple-auth-accounting
   ```

2. **Start the development environment**:

   ```bash
   docker-compose -f docker-compose.dev.yml up
   ```

   This command will:
   - Start a MongoDB instance
   - Start a MailHog server for email testing
   - Build and start the authentication service

3. **Access the services**:
   - API: <http://localhost:3000>
   - Email testing interface: <http://localhost:8025> (for viewing sent emails)

### Option 2: Local Setup without Docker

If you prefer not to use Docker, you can set up the project locally:

1. **Clone the repository**:

   ```bash
   git clone https://github.com/yourusername/simple-auth-accounting.git
   cd simple-auth-accounting
   ```

2. **Install dependencies**:

   ```bash
   npm install
   # or
   yarn install
   ```

3. **Set up environment variables**:

   Create a `.env.development` file in the root directory:

   ```
   PORT=3000
   NODE_ENV=development
   MONGO_URI=mongodb://localhost:27017/auth_db
   JWT_ACCESS_SECRET=your_access_secret_key
   JWT_REFRESH_SECRET=your_refresh_secret_key
   JWT_ACCESS_EXPIRES_IN=15m
   JWT_REFRESH_EXPIRES_IN=7d
   EMAIL_HOST=localhost
   EMAIL_PORT=1025
   EMAIL_USER=
   EMAIL_PASS=
   EMAIL_FROM=noreply@example.com
   PASSWORD_RESET_EXPIRES_IN=1h
   VERIFICATION_CODE_EXPIRES_IN=15m
   FRONTEND_URL=http://localhost:3000
   CORS_ORIGIN=http://localhost:3000
   LOG_LEVEL=info
   ```

4. **Start MongoDB** (if using local instance):

   ```bash
   # Windows
   mongod --dbpath C:\data\db

   # Linux/macOS
   mongod --dbpath /data/db
   ```

5. **Start the development server**:

   ```bash
   npm run dev
   # or
   yarn dev
   ```

## Running the Application

After completing the setup, the authentication system will be running at `http://localhost:3000`. You can test the API endpoints using tools like [Postman](https://www.postman.com/) or [curl](https://curl.se/).

### Health Check

Verify that the system is running properly:

```bash
curl http://localhost:3000/health
```

Expected response: `{"status":"ok"}`

## API Endpoints

The system exposes the following API endpoints:

### Auth Routes (`/api/auth`)

| Endpoint | Method | Description | Access Level |
|----------|--------|-------------|--------------|
| `/api/auth/signup` | POST | Register a new user | Public |
| `/api/auth/verify-email` | POST | Verify email with token | Public |
| `/api/auth/resend-verification` | POST | Resend verification code | Public |
| `/api/auth/login` | POST | Login with credentials | Public |
| `/api/auth/refresh` | POST | Refresh access token | Public |
| `/api/auth/logout` | POST | Logout (invalidate token) | Public |
| `/api/auth/logout-all` | POST | Logout from all devices | Authenticated |
| `/api/auth/forgot-password` | POST | Request password reset | Public |
| `/api/auth/reset-password` | POST | Reset password with token | Public |

### Protected Routes (`/api/protected`)

| Endpoint | Method | Description | Access Level |
|----------|--------|-------------|--------------|
| `/api/protected/profile` | GET | Get user profile | Authenticated |
| `/api/protected/profile` | PUT | Update user profile | Authenticated |
| `/api/protected/change-password` | POST | Change password | Authenticated |
| `/api/protected/dashboard` | GET | Access protected dashboard content | Authenticated |

### Admin Routes (`/api/admin`)

| Endpoint | Method | Description | Access Level |
|----------|--------|-------------|--------------|
| `/api/admin/users` | GET | Get all users | Admin |
| `/api/admin/users` | POST | Create a new user | Admin |
| `/api/admin/users` | DELETE | Delete all users | Admin |
| `/api/admin/users/:userId` | DELETE | Delete a specific user | Admin |
| `/api/admin/users/:userId/role` | PUT | Update user role | Admin |
| `/api/admin/reports` | GET | Access reports | Admin/Supervisor |
| `/api/admin/dashboard` | GET | Access dashboard | Any Authenticated |

## Authentication Flow

### User Registration and Email Verification

1. User registers with email, username, and password
2. System creates a new user record with an unverified status
3. System generates and sends a verification code via email
4. User submits the verification code to verify their email
5. System marks the user as verified

Example for registering a new user:

```bash
curl -X POST http://localhost:3000/api/auth/signup \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","email":"test@example.com","password":"SecurePassword123!"}'
```

### Login and Token Management

1. User logs in with username/email and password
2. System validates credentials and issues:
   - Access token (short-lived, typically 15 minutes)
   - Refresh token (longer-lived, typically 7 days)
3. Client stores these tokens
4. Client includes the access token in subsequent API requests
5. When the access token expires, client uses the refresh token to get a new access token

Example for logging in:

```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"SecurePassword123!"}'
```

### Password Reset Flow

1. User requests a password reset via email
2. System generates a reset token and sends it via email
3. User submits the token with a new password
4. System verifies the token and updates the password

## Role-Based Access Control

The system implements a hierarchical role structure:

1. **Admin** (`admin`) - Complete system access with user management capabilities
2. **Supervisor** (`supervisor`) - Access to reports and limited management features
3. **User/EndUser** (`enduser`) - Basic application access

Each higher role inherits all permissions from the roles below it.

### Creating an Admin User

For first-time setup, you'll need to create an admin user:

1. Sign up a regular user via the API
2. Access MongoDB to update the user's role:

   ```bash
   # If using Docker
   docker exec -it auth-mongodb mongosh

   # In the MongoDB shell
   use auth_db
   db.users.updateOne(
     { username: "admin" },
     { $set: { role: "admin", isVerified: true } }
   )
   ```

## Email Configuration

### Development Environment

In the development environment, the system uses MailHog for email testing. You can access the MailHog web interface at <http://localhost:8025> to view all sent emails.

### Production Environment

For production, configure a real email service:

1. Update your `.env.production` file with appropriate email settings:

   ```
   EMAIL_SERVICE=smtp  # or other service like 'ses', 'sendgrid'
   EMAIL_HOST=smtp.your-provider.com
   EMAIL_PORT=587
   EMAIL_USER=your-email@example.com
   EMAIL_PASS=your-email-password
   EMAIL_FROM=noreply@your-domain.com
   ```

2. If using AWS SES or other cloud providers, ensure proper authentication is set up.

## Testing

The project includes comprehensive testing capabilities:

### Running Unit Tests

```bash
# Run Jest unit tests
npm test
```

### Running Docker-based Tests

```bash
# Run tests in Docker environment
docker-compose -f docker-compose.dev.yml run auth-test
```

### Deployment Validation Tests

```bash
# Run deployment validation tests
cd tests
python deploy_test.py --url http://localhost:3000
```

The `deploy_test.py` script generates detailed JSON reports in the `tests` directory that help you verify system functionality:

- Health check
- User registration and login
- Email verification
- Token refresh mechanism
- Protected route access
- Password reset flow

## Troubleshooting

### Common Issues

1. **MongoDB Connection Issues**
   - Verify MongoDB is running: `docker ps` or `ps aux | grep mongo`
   - Check connection string in environment variables

2. **Email Sending Problems**
   - For development: ensure MailHog is running
   - For production: verify email provider credentials

3. **JWT Token Issues**
   - Check that JWT secrets are properly set in environment variables
   - Verify token expiration times are appropriate

4. **Docker Compatibility Issues**
   - On Windows, check for port conflicts
   - For ARM-based systems (M1/M2 Macs), see architecture compatibility notes in the TestingGuide.md

### Checking Logs

Access logs for troubleshooting:

```bash
# Application logs (if using Docker)
docker logs auth-service-dev

# MongoDB logs (if using Docker)
docker logs auth-mongodb
```

## Advanced Configurations

### Customizing Token Expiration

Adjust the token expiration times in your environment variables:

```
JWT_ACCESS_EXPIRES_IN=30m  # 30 minutes
JWT_REFRESH_EXPIRES_IN=14d  # 14 days
```

### Adding Custom User Fields

To add custom fields to the user model, modify the User schema in `src/models/user.model.ts`.

### Data Migration

If you need to migrate data from an old database:

1. Configure the source database in your environment:

   ```
   OLD_MONGODB_URI=mongodb://localhost:27017/old_auth_db
   ```

2. Run the migration scripts:

   ```bash
   npm run migrate-users
   npm run migrate-tokens
   npm run migrate-verifications
   # Or run all migrations at once
   npm run migrate-all
   ```

## Production Deployment

### Using Docker Compose for Production

1. Configure production environment:

   ```bash
   # Create a secure production environment file
   cp .env.example .env.production
   # Edit with secure credentials
   nano .env.production
   ```

2. Start the production environment:

   ```bash
   docker-compose -f docker-compose.prod.yml up -d
   ```

### Security Best Practices for Production

1. Use strong, random secrets for JWT tokens:

   ```bash
   # Generate secure random strings for JWT tokens
   openssl rand -base64 32  # Use output for JWT_ACCESS_SECRET
   openssl rand -base64 32  # Use output for JWT_REFRESH_SECRET
   ```

2. Enable HTTPS:
   - Always use HTTPS in production
   - Configure a reverse proxy like Nginx with SSL

3. Secure MongoDB:
   - Use strong passwords
   - Only allow connections from your application server
   - Enable authentication

4. Rate Limiting:
   - The system includes rate limiting for sensitive endpoints
   - Adjust rate limits as needed for your use case

## AWS Deployment

For deploying to AWS, the system provides a detailed guide for using Amazon ECS with Fargate and MongoDB Atlas:

1. Set up an AWS account with appropriate IAM user
2. Create an ECR repository for your Docker image
3. Set up an ECS cluster using Fargate
4. Create a MongoDB Atlas database
5. Configure environment variables using AWS secrets manager
6. Deploy using the task definition and service

For complete step-by-step instructions, refer to the `Guide/AwsDeploymentGuide.md` file.

## Additional Resources

Detailed guides are available in the `Guide` directory:

- [Deployment Guide](Guide/DeploymentGuide.md): Detailed deployment instructions
- [Testing Guide](Guide/TestingGuide.md): Comprehensive testing procedures
- [Background Knowledge](Guide/BackgroundKnowledge.md): Technical implementation details
- [JWT Guide](Guide/JWTAccountingGuide.md): JWT token design and usage
- [AWS Deployment Guide](Guide/AwsDeploymentGuide.md): Step-by-step AWS deployment instructions

---

This documentation is designed to help beginners get started with the Simple Authentication and Accounting System. For more detailed information on specific topics, refer to the specialized guides in the `Guide` directory.
