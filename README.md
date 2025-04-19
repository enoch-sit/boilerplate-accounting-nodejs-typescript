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
| `/api/admin/users`             | POST   | Create a new user                     | Admin             |
| `/api/admin/users/:userId/role`| PUT    | Update user role                      | Admin             |
| `/api/admin/reports`           | GET    | Access reports                        | Admin/Supervisor  |
| `/api/admin/dashboard`         | GET    | Access dashboard                      | Any Authenticated |

## Installation

### Prerequisites

- Node.js (v18+)
- MongoDB (Local or Atlas)
- npm or yarn

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

   Create a [`.env.development`](.env.development ) file in the root directory:

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

## Technologies

- **Backend**: Node.js, Express
- **Language**: TypeScript
- **Database**: MongoDB, Mongoose
- **Authentication**: JSON Web Tokens (JWT)
- **Email**: Nodemailer (MailHog for development, AWS SES for production)
- **Security**: Helmet, rate limiting, CORS
- **Logging**: Winston

## Testing

The project includes comprehensive testing capabilities:

```bash
# Run Jest unit tests
npm test
```

## License

MIT License. See [`LICENSE`](LICENSE ) for details.
