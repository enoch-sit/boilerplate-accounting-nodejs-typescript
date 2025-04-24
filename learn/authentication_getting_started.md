# Getting Started with Simple Accounting Authentication

This guide is designed to help newcomers understand and use the authentication system in the Simple Accounting project.

## Table of Contents
1. [System Overview](#system-overview)
2. [Project Structure](#project-structure)
3. [Authentication Flow](#authentication-flow)
4. [Setting Up Your Environment](#setting-up-your-environment)
5. [Common Operations](#common-operations)
6. [Troubleshooting](#troubleshooting)

## System Overview

This is a TypeScript-based authentication system built with Express.js. It provides secure user authentication with features like:

- User registration and login
- JWT (JSON Web Token) for authentication
- Password hashing with bcrypt
- Email verification
- Admin user management
- Protected routes
- CORS configuration for cross-origin requests

The system follows modern security practices and can be used as a starter for accounting applications or any project requiring authentication.

## Project Structure

The authentication system follows a modular structure:

- **auth/**: Contains authentication middleware, services, and token management
- **config/**: Database and email configuration
- **models/**: MongoDB models for users, tokens, and verification
- **routes/**: API endpoints for authentication, protected resources, and admin functions
- **services/**: Supporting services for email and password management
- **utils/**: Utilities for error handling, logging, and validation

## Authentication Flow

Here's the basic flow for user authentication:

1. **Registration**: User submits registration info → System validates → Creates user record → Sends verification email
2. **Verification**: User clicks verification link → System verifies → Account activated
3. **Login**: User submits credentials → System validates → Issues JWT token (stored in cookie) → User authenticated
4. **Accessing Protected Resources**: User makes request with JWT → System validates token → Grants/denies access
5. **Logout**: User logs out → JWT invalidated

## Setting Up Your Environment

### Prerequisites
- Node.js (v14+)
- MongoDB
- npm or yarn

### Installation Steps
1. Clone the repository
2. Install dependencies:
   ```
   npm install
   ```
3. Set up environment variables (copy `.env.development.example` to `.env.development` and customize)
4. Start the development server:
   ```
   npm run dev
   ```

### Environment Variables
Key environment variables include:
- `PORT`: Server port (default: 3000)
- `MONGODB_URI`: MongoDB connection string
- `JWT_SECRET`: Secret for signing JWTs
- `CORS_ORIGIN`: Allowed origin for CORS (e.g., http://localhost:5173)
- `EMAIL_*`: SMTP email configuration

## Common Operations

### Creating a User
```typescript
// Example API request to register a user
fetch('http://localhost:3000/api/auth/register', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    email: 'user@example.com',
    password: 'SecurePassword123!',
    firstName: 'John',
    lastName: 'Doe'
  })
})
```

### Logging In
```typescript
// Example API request to login
fetch('http://localhost:3000/api/auth/login', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  },
  credentials: 'include', // Important for receiving cookies
  body: JSON.stringify({
    email: 'user@example.com',
    password: 'SecurePassword123!'
  })
})
```

### Making Authenticated Requests
```typescript
// Example of accessing a protected resource
fetch('http://localhost:3000/api/profile', {
  method: 'GET',
  credentials: 'include' // Important for sending cookies with the request
})
```

## Troubleshooting

### Common CORS Issues
If you're getting CORS errors:
1. Ensure the client's origin matches what's in the `CORS_ORIGIN` environment variable
2. Make sure to include `credentials: 'include'` in fetch requests
3. The server is configured to handle credentials properly

### JWT Issues
If authentication fails:
1. Check that cookies are being sent correctly
2. Ensure JWT hasn't expired
3. Verify that the `JWT_SECRET` hasn't changed

### Database Connection
If database connection fails:
1. Verify MongoDB is running
2. Check the `MONGODB_URI` in your environment variables
3. Ensure network connectivity to the database

For more detailed information, please check the additional documentation in the Guide folder.