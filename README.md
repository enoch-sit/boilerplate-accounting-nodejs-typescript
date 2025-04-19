# Simple Authentication and Accounting System with TypeScript and MongoDB using JWT

A robust authentication system built with TypeScript, Express, and MongoDB. Features include user registration, email verification, JWT authentication, password reset, and protected routes with role-based access control.

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
| `/api/admin/users`             | POST   | Create a new user                     | Admin             |
| `/api/admin/users/:userId/role`| PUT    | Update user role                      | Admin             |
| `/api/admin/reports`           | GET    | Access reports                        | Admin/Supervisor  |
| `/api/admin/dashboard`         | GET    | Access dashboard                      | Any Authenticated |

## System Architecture

The authentication system follows a modern architecture with:

- **Express.js Backend**: Handles API requests and implements business logic
- **MongoDB Database**: Stores user data, tokens, and verification records
- **JWT Authentication**: Secure token-based authentication with refresh mechanism
- **Role-Based Access Control**: Hierarchical permission structure
- **Email Service Integration**: For verification and password reset processes

## Role-Based Access Control

The system implements a hierarchical role structure:

1. **Admin** (`admin`) - Complete system access with user management capabilities
2. **Supervisor** (`supervisor`) - Access to reports and limited management features
3. **User/EndUser** (`enduser`) - Basic application access

Each higher role inherits all permissions from the roles below it.

## Installation

### Prerequisites

- Node.js (v18+)
- MongoDB (Local or Atlas)
- npm or yarn
- Python 3.x (for deployment testing scripts)

### Local Setup

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
   EMAIL_HOST=smtp.example.com
   EMAIL_PORT=587
   EMAIL_USER=your_email@example.com
   EMAIL_PASS=your_email_password
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

   The server will be running at `http://localhost:3000`.

### Docker Setup

For an easier setup using Docker:

1. **Install Docker** from [docker.com](https://www.docker.com/get-started)

2. **Start the development environment**:

   ```bash
   docker-compose -f docker-compose.dev.yml up
   ```

   This will start:
   - The authentication service on port 3000
   - MongoDB on port 27017
   - MailHog (for email testing) on port 8025 (UI) and 1025 (SMTP)

3. **Access the services**:
   - API: <http://localhost:3000>
   - Email testing interface: <http://localhost:8025>

## Production Deployment

### Using Docker Compose

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

### Creating an Admin User

For first-time setup, you'll need to create an admin user:

0. Curl Example:

      ```cmd
      curl -X POST http://localhost:3000/api/auth/signup -H "Content-Type: application/json" -d "{\"username\":\"admin\",\"email\":\"admin@example.com\",\"password\":\"admin@admin\"}"
      ```

1. Verification Code (replace the verification code with your verification code)

      ```cmd
      curl -X POST http://localhost:3000/api/auth/verify-email -H "Content-Type: application/json" -d "{\"token\":\"14D71C\"}"
      ```

2. Sign up a regular user via the API
3. Go into the database (inside docker)

   ```cmd
   docker exec -it auth-mongodb mongosh
   ```

4. Use the auth_db

   ```cmd
   use auth_db
   ```

5. Access MongoDB to update the user's role (if not verify):

   ```javascript
   db.users.updateOne(
     { username: "admin" },
     { $set: { role: "admin", isVerified: true } }
   )
   ```

## Testing

The project includes comprehensive testing capabilities:

```bash
# Run Jest unit tests
npm test

# Run in Docker
docker-compose -f docker-compose.dev.yml run auth-test

# Run deployment validation tests
cd tests
python deploy_test.py --url http://localhost:3000
```

### Deployment Testing Reports

The `deploy_test.py` script generates detailed JSON reports in the `tests` directory that help you verify system functionality:

- Health check
- User registration and login
- Email verification
- Token refresh mechanism
- Protected route access
- Password reset flow

### MailHog for Email Testing

During development, MailHog captures all outgoing emails for testing. Access the web interface at <http://localhost:8025> to view emails sent by the system.

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

## Additional Documentation

Detailed guides are available in the `Guide` directory:

- [Deployment Guide](Guide/DeploymentGuide.md): Detailed deployment instructions
- [Testing Guide](Guide/TestingGuide.md): Comprehensive testing procedures
- [Background Knowledge](Guide/BackgroundKnowledge.md): Technical implementation details
- [JWT Guide](Guide/JWTAccountingGuide.md): JWT token design and usage

## Technologies

- **Backend**: Node.js, Express
- **Language**: TypeScript
- **Database**: MongoDB, Mongoose
- **Authentication**: JSON Web Tokens (JWT)
- **Email**: Nodemailer (MailHog for development, AWS SES for production)
- **Security**: Helmet, rate limiting, CORS, bcrypt password hashing
- **Logging**: Winston
- **Testing**: Jest, Supertest
- **Containerization**: Docker, Docker Compose

## Security Features

- Secure password hashing with bcrypt
- Short-lived JWT access tokens with refresh mechanism
- Rate limiting on authentication endpoints
- Email verification for new accounts
- Secure password reset flow
- Role-based access control
- HTTP security headers with Helmet
- CORS protection

## License

MIT License. See [`LICENSE`](LICENSE) for details.
