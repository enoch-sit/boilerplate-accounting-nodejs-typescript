# Authentication Service Code Map

This document provides a comprehensive overview of the authentication service architecture and flows in the Simple Accounting application.

## System Architecture

The authentication system is built on TypeScript and follows a modular architecture with clear separation of concerns.

```mermaid
graph TD
    A[Client Application] --> |HTTP Requests| B[Express Server - app.ts]
    B --> |Routes| C[Routes]
    C --> |Auth Routes| D[auth.routes.ts]
    C --> |Admin Routes| E[admin.routes.ts]
    C --> |Protected Routes| F[protected.routes.ts]
    C --> |Testing Routes| G[testing.routes.ts]
    
    D --> |Auth Services| H[auth.service.ts]
    E --> |Auth Services| H
    F --> |Auth Services| H
    
    D --> |Auth Middleware| I[auth.middleware.ts]
    E --> |Auth Middleware| I
    F --> |Auth Middleware| I
    
    H --> |Token Operations| J[token.service.ts]
    H --> |Password Operations| K[password.service.ts]
    H --> |Email Operations| L[email.service.ts]
    
    H --> |Database Models| M[Models]
    J --> |Database Models| M
    K --> |Database Models| M
    
    M --> |User Model| N[user.model.ts]
    M --> |Token Model| O[token.model.ts]
    M --> |Verification Model| P[verification.model.ts]
    
    H --> |Utils| Q[Utils]
    J --> |Utils| Q
    K --> |Utils| Q
    L --> |Utils| Q
    
    Q --> |Logger| R[logger.ts]
    Q --> |Validators| S[validators.ts]
    Q --> |Error Handler| T[error-handler.ts]
    
    B --> |Config| U[Config]
    U --> |DB Config| V[db.config.ts]
    U --> |Email Config| W[email.config.ts]
```

## Core Components Overview

### Models

1. **User Model** (`user.model.ts`)
   - Defines the schema for user data
   - Implements password hashing with bcryptjs
   - Provides password comparison method
   - Defines user roles (ADMIN, SUPERVISOR, ENDUSER, USER)

2. **Token Model** (`token.model.ts`)
   - Stores refresh tokens
   - Associates tokens with users
   - Tracks token expiration

3. **Verification Model** (`verification.model.ts`)
   - Stores email verification and password reset tokens
   - Associates verification tokens with users
   - Tracks token expiration

### Services

1. **Auth Service** (`auth.service.ts`)
   - Handles user registration and verification
   - Manages login and authentication
   - Provides token refresh and logout functionality
   - Implements admin user management operations

2. **Token Service** (`token.service.ts`)
   - Generates JWT access and refresh tokens
   - Verifies token validity
   - Manages token storage and deletion

3. **Password Service** (`password.service.ts`)
   - Handles password reset functionality
   - Generates secure random passwords
   - Hashes passwords

4. **Email Service** (`email.service.ts`)
   - Sends verification emails
   - Sends password reset emails
   - Sends notifications for admin-created accounts

### Middleware

1. **Auth Middleware** (`auth.middleware.ts`)
   - Authenticates requests using JWT tokens
   - Provides role-based access control
   - Supports optional authentication

### Routes

1. **Auth Routes** (`auth.routes.ts`)
   - User registration and verification
   - Login and logout
   - Password reset

2. **Protected Routes** (`protected.routes.ts`)
   - User profile management
   - Password changes
   - General authenticated user functionality

3. **Admin Routes** (`admin.routes.ts`)
   - User management
   - Batch user creation
   - Role management

4. **Testing Routes** (`testing.routes.ts`)
   - Development and testing utilities

## Authentication Flows

### 1. User Registration and Verification Flow

```mermaid
sequenceDiagram
    participant Client
    participant AuthRoutes as auth.routes.ts
    participant AuthService as auth.service.ts
    participant UserModel as user.model.ts
    participant VerificationModel as verification.model.ts
    participant EmailService as email.service.ts
    
    Client->>AuthRoutes: POST /auth/signup {username, email, password}
    AuthRoutes->>AuthService: signup(username, email, password)
    
    AuthService->>UserModel: Check if username exists
    UserModel-->>AuthService: Username existence status
    
    AuthService->>UserModel: Check if email exists
    UserModel-->>AuthService: Email existence status
    
    AuthService->>UserModel: Create new user
    Note over UserModel: Password hashed by pre-save hook
    UserModel-->>AuthService: Created user
    
    AuthService->>VerificationModel: Generate verification token
    VerificationModel-->>AuthService: Verification token
    
    AuthService->>EmailService: Send verification email
    EmailService-->>AuthService: Email sent status
    
    AuthService-->>AuthRoutes: SignupResult {success, userId, message}
    AuthRoutes-->>Client: 201 Created or 400 Bad Request
    
    Client->>AuthRoutes: POST /auth/verify-email {token}
    AuthRoutes->>AuthService: verifyEmail(token)
    
    AuthService->>VerificationModel: Find verification record
    VerificationModel-->>AuthService: Verification record
    
    AuthService->>UserModel: Update user isVerified = true
    UserModel-->>AuthService: Updated user
    
    AuthService->>VerificationModel: Delete verification record
    VerificationModel-->>AuthService: Deletion status
    
    AuthService-->>AuthRoutes: Verification status
    AuthRoutes-->>Client: 200 OK or 400 Bad Request
```

### 2. User Login Flow

```mermaid
sequenceDiagram
    participant Client
    participant AuthRoutes as auth.routes.ts
    participant AuthService as auth.service.ts
    participant UserModel as user.model.ts
    participant TokenService as token.service.ts
    participant TokenModel as token.model.ts
    
    Client->>AuthRoutes: POST /auth/login {username, password}
    AuthRoutes->>AuthService: login(username, password)
    
    AuthService->>UserModel: Find user by username/email
    UserModel-->>AuthService: User record
    
    AuthService->>UserModel: Check if user is verified
    AuthService->>UserModel: comparePassword(password)
    UserModel-->>AuthService: Password validity
    
    AuthService->>TokenService: generateAccessToken(userId, username, email, role)
    TokenService-->>AuthService: Access token
    
    AuthService->>TokenService: generateRefreshToken(userId, username, email, role)
    TokenService->>TokenModel: Store refresh token
    TokenModel-->>TokenService: Storage confirmation
    TokenService-->>AuthService: Refresh token
    
    AuthService-->>AuthRoutes: LoginResult {success, accessToken, refreshToken, user, message}
    AuthRoutes->>Client: Set HTTP-only cookies
    AuthRoutes-->>Client: 200 OK or 401 Unauthorized
```

### 3. Token Refresh Flow (with Rotation)

```mermaid
sequenceDiagram
    participant Client
    participant AuthRoutes as auth.routes.ts
    participant AuthService as auth.service.ts
    participant TokenService as token.service.ts
    participant TokenModel as token.model.ts
    
    Client->>AuthRoutes: POST /auth/refresh {refreshToken}
    Note over Client, AuthRoutes: Token can be in cookie or request body
    
    AuthRoutes->>AuthService: refreshToken(refreshToken)
    AuthService->>TokenService: verifyRefreshToken(refreshToken)
    
    TokenService->>TokenService: Verify JWT signature
    TokenService->>TokenModel: Find token in database
    TokenModel-->>TokenService: Token record (if exists)
    TokenService-->>AuthService: Decoded token payload or null
    
    alt Valid refresh token
        AuthService->>TokenService: generateAccessToken(userId, username, email, role)
        TokenService-->>AuthService: New access token
        
        AuthService->>TokenService: deleteRefreshToken(oldRefreshToken)
        TokenService->>TokenModel: Remove old refresh token
        TokenModel-->>TokenService: Deletion confirmed
        
        AuthService->>TokenService: generateRefreshToken(userId, username, email, role)
        TokenService->>TokenModel: Store new refresh token
        TokenModel-->>TokenService: Storage confirmed
        TokenService-->>AuthService: New refresh token
        
        AuthService-->>AuthRoutes: TokenRefreshResult {success, accessToken, refreshToken, message}
        AuthRoutes->>Client: Set HTTP-only cookies for both tokens
        AuthRoutes-->>Client: 200 OK with new tokens
    else Invalid refresh token
        AuthService-->>AuthRoutes: TokenRefreshResult {success: false, message}
        AuthRoutes-->>Client: 401 Unauthorized
    end
    
    Note over Client, TokenModel: Token Rotation Security:<br/>Old refresh token is invalidated<br/>New tokens are issued together
```

### 4. Authentication Middleware Flow

```mermaid
sequenceDiagram
    participant Client
    participant ProtectedRoute as Any Protected Route
    participant AuthMiddleware as auth.middleware.ts
    participant TokenService as token.service.ts
    participant NextHandler as Next Route Handler
    
    Client->>ProtectedRoute: Request with Authorization header or cookie
    ProtectedRoute->>AuthMiddleware: authenticate middleware
    
    AuthMiddleware->>AuthMiddleware: Extract token from header or cookie
    AuthMiddleware->>TokenService: verifyAccessToken(token)
    
    TokenService->>TokenService: Verify JWT signature and expiration
    TokenService-->>AuthMiddleware: Decoded token payload or null
    
    alt Token is valid
        AuthMiddleware->>AuthMiddleware: Attach user info to request
        AuthMiddleware->>NextHandler: Next()
        NextHandler-->>Client: Protected resource response
    else Token is invalid or missing
        AuthMiddleware-->>Client: 401 Unauthorized
    end
```

### 5. Role-Based Access Control Flow

```mermaid
sequenceDiagram
    participant Client
    participant AdminRoute as Admin Route
    participant AuthMiddleware as auth.middleware.ts
    participant RoleMiddleware as requireAdmin middleware
    participant Controller as Route Controller
    
    Client->>AdminRoute: Request with Authorization header or cookie
    AdminRoute->>AuthMiddleware: authenticate middleware
    
    AuthMiddleware->>AuthMiddleware: Validate token & attach user info
    AuthMiddleware->>RoleMiddleware: Next()
    
    RoleMiddleware->>RoleMiddleware: Check user.role === 'admin'
    
    alt User is Admin
        RoleMiddleware->>Controller: Next()
        Controller-->>Client: Admin resource response
    else User is not Admin
        RoleMiddleware-->>Client: 403 Forbidden
    end
```

### 6. Password Reset Flow

```mermaid
sequenceDiagram
    participant Client
    participant AuthRoutes as auth.routes.ts
    participant PasswordService as password.service.ts
    participant UserModel as user.model.ts
    participant VerificationModel as verification.model.ts
    participant EmailService as email.service.ts
    
    Client->>AuthRoutes: POST /auth/forgot-password {email}
    AuthRoutes->>PasswordService: generateResetToken(email)
    
    PasswordService->>UserModel: Find user by email
    UserModel-->>PasswordService: User record or null
    
    PasswordService->>VerificationModel: Delete existing reset tokens
    VerificationModel-->>PasswordService: Deletion status
    
    PasswordService->>VerificationModel: Create new reset token
    VerificationModel-->>PasswordService: Token record
    
    PasswordService->>EmailService: sendPasswordResetEmail(email, username, token)
    EmailService-->>PasswordService: Email sent status
    
    PasswordService-->>AuthRoutes: Success status
    AuthRoutes-->>Client: 200 OK (always return success to prevent email enumeration)
    
    Client->>AuthRoutes: POST /auth/reset-password {token, newPassword}
    AuthRoutes->>PasswordService: resetPassword(token, newPassword)
    
    PasswordService->>VerificationModel: Find token record
    VerificationModel-->>PasswordService: Token record or null
    
    PasswordService->>UserModel: Find user and update password
    Note over UserModel: Password hashed by pre-save hook
    UserModel-->>PasswordService: Updated user
    
    PasswordService->>VerificationModel: Delete used token
    VerificationModel-->>PasswordService: Deletion status
    
    PasswordService-->>AuthRoutes: Reset success status
    AuthRoutes-->>Client: 200 OK or 400 Bad Request
```

### 7. Admin User Creation Flow

```mermaid
sequenceDiagram
    participant Admin
    participant AdminRoutes as admin.routes.ts
    participant AuthMiddleware as auth.middleware.ts
    participant RoleMiddleware as requireAdmin middleware
    participant AuthService as auth.service.ts
    participant UserModel as user.model.ts
    participant EmailService as email.service.ts
    
    Admin->>AdminRoutes: POST /admin/users {username, email, password, role}
    AdminRoutes->>AuthMiddleware: authenticate middleware
    AuthMiddleware->>RoleMiddleware: requireAdmin middleware
    RoleMiddleware->>AdminRoutes: Next()
    
    AdminRoutes->>AuthService: adminCreateUser(...)
    
    AuthService->>UserModel: Check if username exists
    UserModel-->>AuthService: Username existence status
    
    AuthService->>UserModel: Check if email exists
    UserModel-->>AuthService: Email existence status
    
    AuthService->>UserModel: Create new user with role
    UserModel-->>AuthService: Created user
    
    alt Skip Verification is false
        AuthService->>VerificationModel: Generate verification token
        VerificationModel-->>AuthService: Token record
        AuthService->>EmailService: Send verification email
        EmailService-->>AuthService: Email sent status
    end
    
    AuthService-->>AdminRoutes: SignupResult
    AdminRoutes-->>Admin: 201 Created or error response
```

## Database Schema

```mermaid
erDiagram
    USER {
        ObjectId _id
        string username
        string email
        string password
        boolean isVerified
        enum role
        date createdAt
        date updatedAt
    }
    
    TOKEN {
        ObjectId _id
        ObjectId userId
        string refreshToken
        date expires
        date createdAt
    }
    
    VERIFICATION {
        ObjectId _id
        ObjectId userId
        enum type
        string token
        date expires
        date createdAt
    }
    
    USER ||--o{ TOKEN : "has many"
    USER ||--o{ VERIFICATION : "has many"
```

## Security Considerations

1. **Password Security**
   - Passwords are hashed using bcryptjs before storage
   - Password requirements enforced (minimum length, complexity)
   - Secure password reset with time-limited tokens

2. **Token Security**
   - JWTs for stateless authentication
   - Short-lived access tokens (15 minutes)
   - HTTP-only cookies for token storage
   - Refresh token rotation

3. **Access Control**
   - Role-based authorization
   - Middleware-based permission checks
   - Route protection

4. **API Security**
   - Rate limiting on authentication endpoints
   - CORS configuration
   - Helmet for HTTP headers security

## Migration Scripts

The system includes migration scripts to help transition data between database versions:

1. **migrate-users.ts** - Migrates user data including role assignment
2. **migrate-tokens.ts** - Migrates refresh tokens 
3. **migrate-verifications.ts** - Migrates verification records
4. **migrate-all.ts** - Orchestrates the complete migration process