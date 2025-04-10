# Deployment Guide: Simple Accounting Authentication System

This guide provides detailed instructions for deploying the Simple Accounting Authentication System in different environments. It covers both development and production setups using Docker.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Development Environment Setup](#development-environment-setup)
- [Production Environment Setup](#production-environment-setup)
- [Environment Configuration](#environment-configuration)
- [Database Setup and Migration](#database-setup-and-migration)
- [Testing Your Deployment](#testing-your-deployment)
- [Interpreting Deployment Test Reports](#interpreting-deployment-test-reports)
- [Admin User Management](#admin-user-management)
- [Troubleshooting](#troubleshooting)

## Prerequisites

Before deploying the system, ensure you have the following prerequisites installed:

- [Docker](https://www.docker.com/get-started) and Docker Compose
- [Node.js](https://nodejs.org/) (v14 or higher) for local development
- [MongoDB](https://www.mongodb.com/try/download/community) (if not using Docker)

## Development Environment Setup

### Using Docker Compose for Development

The easiest way to set up the development environment is using Docker Compose:

1. Clone the repository:

   ```bash
   git clone <repository-url>
   cd simple-accounting
   ```

2. Start the development environment:

   ```bash
   docker-compose -f docker-compose.dev.yml up
   ```

This will spin up several containers:

- `auth-service-dev`: The main application running in development mode
- `mongodb`: MongoDB database server
- `mailhog`: Email testing service with web interface (accessible at <http://localhost:8025>)

### Development Environment Components

The development environment includes:

- **API Server**: Running on <http://localhost:3000>
- **Database**: MongoDB instance accessible at localhost:27017
- **Mail Server**: MailHog running on SMTP port 1025, UI on port 8025

### Local Development Without Docker

If you prefer to develop without Docker:

1. Install dependencies:

   ```bash
   npm install
   ```

2. Create a `.env.development` file in the project root with appropriate configurations:

   ```
   MONGO_URI=mongodb://localhost:27017/auth_db
   OLD_MONGODB_URI=mongodb://localhost:27017/old_auth_db
   EMAIL_SERVICE=smtp
   EMAIL_HOST=localhost
   EMAIL_PORT=1025
   EMAIL_USER=
   EMAIL_PASS=
   NODE_ENV=development
   JWT_ACCESS_SECRET=access_secret
   JWT_REFRESH_SECRET=refresh_secret
   JWT_ACCESS_EXPIRES_IN=15m
   JWT_REFRESH_EXPIRES_IN=7d
   VERIFICATION_CODE_EXPIRES_IN=15m
   PASSWORD_RESET_EXPIRES_IN=1h
   FRONTEND_URL=http://localhost:3000
   EMAIL_FROM=noreply@example.com
   CORS_ORIGIN=http://localhost:3000
   LOG_LEVEL=info
   PORT=3000
   ```

3. Start the development server:

   ```bash
   npm run dev
   ```

## Production Environment Setup

### Using Docker Compose for Production

1. Configure the production environment:
   - Create a `.env.production` file with secure credentials
   - Update the `docker-compose.prod.yml` file if necessary

2. Build and start the production environment:

   ```bash
   docker-compose -f docker-compose.prod.yml up -d
   ```

### Manual Production Deployment

For a manual production deployment:

1. Build the application:

   ```bash
   npm run build
   ```

2. Set up environment variables or create a `.env.production` file

3. Start the application:

   ```bash
   NODE_ENV=production npm start
   ```

## Environment Configuration

Both development and production environments use environment variables for configuration.

### Key Environment Variables

| Variable | Description | Example Value |
|----------|-------------|---------------|
| `MONGO_URI` | MongoDB connection string | `mongodb://mongodb:27017/auth_db` |
| `JWT_ACCESS_SECRET` | Secret for signing access tokens | `your_secure_access_secret` |
| `JWT_REFRESH_SECRET` | Secret for signing refresh tokens | `your_secure_refresh_secret` |
| `JWT_ACCESS_EXPIRES_IN` | Access token expiration | `15m` |
| `JWT_REFRESH_EXPIRES_IN` | Refresh token expiration | `7d` |
| `EMAIL_HOST` | SMTP server host | `smtp.gmail.com` |
| `EMAIL_PORT` | SMTP server port | `587` |
| `EMAIL_USER` | SMTP username | `your_email@example.com` |
| `EMAIL_PASS` | SMTP password | `your_email_password` |
| `EMAIL_FROM` | From address for emails | `noreply@example.com` |
| `VERIFICATION_CODE_EXPIRES_IN` | Email verification expiration | `15m` |
| `PASSWORD_RESET_EXPIRES_IN` | Password reset token expiration | `1h` |
| `FRONTEND_URL` | Frontend application URL | `https://yourdomain.com` |
| `CORS_ORIGIN` | CORS allowed origins | `https://yourdomain.com` |
| `LOG_LEVEL` | Logging level | `info` |

### Security Considerations

For production environments:

- Use strong, random secrets for JWT tokens
- Configure secure email providers with proper authentication
- Set appropriate CORS origins to restrict cross-origin access
- Use HTTPS for all production endpoints
- Store sensitive environment variables in a secure vault or service

## Database Setup and Migration

### Initial Database Setup

When using Docker, the MongoDB instance is automatically created. For manual setups:

1. Create the database:

   ```javascript
   use auth_db
   ```

2. Create a database user (for production):

   ```javascript
   db.createUser({
     user: "auth_user",
     pwd: "secure_password",
     roles: [{ role: "readWrite", db: "auth_db" }]
   })
   ```

### Data Migration

To migrate data from an old database:

1. Configure the source database in your environment:

   ```
   OLD_MONGODB_URI=mongodb://localhost:27017/old_auth_db
   ```

2. Run the migration scripts:

   ```bash
   npm run migrate-users
   npm run migrate-tokens
   npm run migrate-verifications
   ```

   Or run all migrations at once:

   ```bash
   npm run migrate-all
   ```

## Testing Your Deployment

### Automated Tests

1. Run the test suite:

   ```bash
   npm test
   ```

2. For Docker-based testing:

   ```bash
   docker-compose -f docker-compose.dev.yml run auth-test
   ```

### Deployment Tests

Use the deployment test script to validate your setup:

1. Run the deployment test:

   ```bash
   cd tests
   python deploy_test.py --url http://localhost:3000
   ```

2. Check the test results. All tests should pass, especially:
   - Health check
   - User registration
   - Email verification
   - Login/token handling
   - Protected routes access
   - Password reset flow

## Interpreting Deployment Test Reports

When you run the deployment tests using the `deploy_test.py` script, it generates detailed JSON reports in the `tests` directory with filenames like `deploy_test_report_YYYYMMDD_HHMMSS.json`. These reports provide valuable insights into the health and functionality of your deployed system.

### Understanding the Test Report Structure

A test report contains the following key information:

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
    // Other test results...
  ]
}
```

### Key Metrics in the Report

1. **Overall Pass Rate**: The percentage of tests that passed (e.g., 90.0%)
2. **Individual Test Results**: Each test's name, status (passed/failed), and timestamp
3. **Test Details**: Additional information about each test's response

### Critical Tests to Monitor

Pay special attention to these tests as they represent core functionality:

1. **Health Check**: Verifies the API server is up and responsive
2. **User Sign Up**: Tests the registration flow
3. **Email Verification**: Ensures the email verification process works
4. **User Login**: Tests authentication
5. **Access Protected Route**: Validates authorization
6. **Refresh Token**: Checks token refresh mechanism
7. **Password Reset Flow**: Tests password reset functionality

### Common Test Failures and Solutions

| Test Failure | Possible Causes | Solution |
|--------------|-----------------|----------|
| Health Check | API server down or network issues | Check if the service is running: `docker ps` |
| User Sign Up | Database connection issues | Verify MongoDB is accessible |
| Email Verification | Email service configuration problems | Check MailHog or email provider settings |
| User Login | Authentication service issues | Verify JWT secrets are configured correctly |
| Access Protected Route | Authorization middleware errors | Check role-based access control configuration |
| Refresh Token | Token service issues | Ensure refresh token secrets and expiration are set |
| Password Reset | Email or database issues | Verify both email and database connections |

### Using Reports for Continuous Monitoring

Deploy test reports can be used for continuous monitoring by setting up scheduled test runs:

```bash
# Example cron job to run tests every hour
0 * * * * cd /path/to/project && python tests/deploy_test.py --url http://your-api-url > /var/log/deploy-tests.log 2>&1
```

This will generate regular reports to help you monitor system health over time.

### Archiving and Analyzing Historical Reports

Test reports are saved with timestamps, allowing you to track system stability over time:

1. **Archive Reports**: Store reports for long-term analysis
2. **Trend Analysis**: Compare pass rates across multiple reports
3. **Regression Detection**: Identify when previously passing tests start failing

For example, if a report shows the "Refresh Token" test failing, but it was passing in previous reports, you can investigate recent changes that might have affected this functionality.

## Admin User Management

### Default Admin Credentials

The application is designed with role-based access control, with admin users having the highest level of privileges. The default admin credentials are:
- Username: `admin`
- Password: `AdminPassword123!`

These credentials are not automatically created on first deployment. If the application is being deployed for the first time, you will need to create an admin user.

### Creating an Admin User

There are several ways to create an admin user:

#### Method 1: Direct Database Modification

This is the most reliable method when you're first setting up the system:

1. Create a regular user through the signup API:
   ```bash
   curl -X POST http://localhost:3000/api/auth/signup \
     -H "Content-Type: application/json" \
     -d '{"username":"admin","email":"admin@example.com","password":"AdminPassword123!"}'
   ```

2. Connect to the MongoDB instance:
   ```bash
   docker exec -it auth-mongodb mongosh
   ```

3. Switch to the auth database:
   ```
   use auth_db
   ```

4. Update the user's role to admin and mark it as verified:
   ```
   db.users.updateOne(
     { username: "admin" },
     { $set: { role: "admin", isVerified: true } }
   )
   ```

   The update operation should return `{ "acknowledged": true, "matchedCount": 1, "modifiedCount": 1 }` if successful.

#### Method 2: Using an Existing Admin Account

If an admin already exists, they can create other users (including admin users):

1. Log in as an existing admin user:
   ```bash
   curl -X POST http://localhost:3000/api/auth/login \
     -H "Content-Type: application/json" \
     -d '{"username":"admin","password":"AdminPassword123!"}'
   ```

2. Use the returned token to create a supervisor user:
   ```bash
   curl -X POST http://localhost:3000/api/admin/users \
     -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{
       "username": "supervisor",
       "email": "supervisor@example.com",
       "password": "SupervisorPass123!",
       "role": "supervisor",
       "skipVerification": true
     }'
   ```

**Note:** For security reasons, even admins cannot directly create other admin users through the API. This is an intentional security measure to prevent privilege escalation. Only direct database modification can create admin users.

### Understanding Role Hierarchy

The system implements a hierarchical role structure:

1. **Admin** (`admin`) - Complete system access
2. **Supervisor** (`supervisor`) - Access to reports and management features
3. **User/EndUser** (`enduser`) - Basic application access

Each higher role inherits all permissions from the roles below it. This hierarchy is enforced by middleware functions in the `auth.middleware.ts` file.

### How Role-Based Authorization Works

The role-based authorization system works through these key components:

1. **User Model**: Stores the user's role in the `role` field.
   ```typescript
   // src/models/user.model.ts
   export enum UserRole {
     ADMIN = 'admin',
     SUPERVISOR = 'supervisor',
     ENDUSER = 'enduser'
   }
   ```

2. **Token Service**: Includes the role in JWT tokens
   ```typescript
   // Role is included in the payload
   const payload: TokenPayload = { 
     sub: userId,
     username, 
     type: 'access', 
     role 
   };
   ```

3. **Auth Middleware**: Verifies the role from the token and restricts access
   ```typescript
   // Example: Admin check middleware
   export const requireAdmin = (req, res, next) => {
     if (req.user.role !== UserRole.ADMIN) {
       return res.status(403).json({ error: 'Admin access required' });
     }
     next();
   };
   ```

4. **Route Protection**: API endpoints are protected with the appropriate middleware
   ```typescript
   // Example: Admin-only route
   router.get('/users', authenticate, requireAdmin, userController.getAllUsers);
   ```

This design ensures that only users with the appropriate role can access restricted functionality, creating a secure and well-organized permission system.

## Troubleshooting

### Common Issues

1. **Connection Refused to Database**
   - Check if MongoDB is running
   - Verify the MONGO_URI environment variable

2. **Email Sending Fails**
   - Check email provider settings
   - For development, verify MailHog is running
   - Test connection to SMTP server

3. **Token Refresh Issues**
   - Ensure JWT_REFRESH_SECRET is correctly set
   - Check token expiration times

4. **CORS Errors**
   - Verify CORS_ORIGIN configuration matches your frontend origin

### Logs and Debugging

Access logs for troubleshooting:

- **Application logs**:

  ```bash
  docker logs auth-service-dev
  ```

- **Database logs**:

  ```bash
  docker logs auth-mongodb
  ```

- **Email logs (Development)**:
  Access MailHog web interface at <http://localhost:8025>

## Additional Resources

- [API Documentation](../README.md#api-endpoints)
- [Background Knowledge Guide](./BackgroundKnowledge.md)
- [JWT Authentication Guide](./JWTAccountingGuide.md)
- [Testing Guide](./TestingGuide.md)
