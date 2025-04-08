# Technical Documentation: TypeScript Authentication System

This document provides a comprehensive technical overview of the TypeScript Authentication System, including database structure, API architecture, authentication workflows, and testing methodologies.

## Table of Contents

1. [System Architecture](#system-architecture)
2. [Database Structure](#database-structure)
3. [API Structure](#api-structure)
4. [Authentication Workflows](#authentication-workflows)
5. [API Usage Steps](#api-usage-steps)
6. [Role-Based Access Control](#role-based-access-control)
7. [Testing Scope](#testing-scope)
8. [Security Considerations](#security-considerations)

## System Architecture

The authentication system follows a modern Node.js/Express architecture with TypeScript for type safety and MongoDB for data persistence.

```mermaid
graph TB
    Client[Client Application]
    API[Express API Server]
    Auth[Authentication Service]
    Token[Token Service]
    DB[(MongoDB)]
    Email[Email Service]
    
    Client <--> API
    API --> Auth
    API --> Token
    Auth --> DB
    Auth --> Email
    Auth --> Token
    Token --> DB
    
    classDef primary fill:#4285F4,stroke:#0D47A1,color:white;
    classDef secondary fill:#34A853,stroke:#0F9D58,color:white;
    classDef data fill:#FBBC05,stroke:#F57C00,color:white;
    classDef service fill:#EA4335,stroke:#B31412,color:white;
    
    class Client,API primary
    class Auth,Token secondary
    class DB data
    class Email service
```

## Database Structure

The system uses MongoDB with three primary collections: Users, Tokens, and Verifications. Below is a diagram showing the database schema and relationships:

```mermaid
erDiagram
    User {
        ObjectId _id
        string username
        string email
        string password
        boolean isVerified
        enum role
        date createdAt
        date updatedAt
    }
    
    Token {
        ObjectId _id
        ObjectId userId
        string refreshToken
        date expires
        date createdAt
        date updatedAt
    }
    
    Verification {
        ObjectId _id
        ObjectId userId
        enum type
        string token
        date expires
        date createdAt
        date updatedAt
    }
    
    User ||--o{ Token : "has many"
    User ||--o{ Verification : "has many"
    
```

### Collection Details

#### User Collection
- Stores user credentials and profile information
- Password is hashed using bcrypt before storage
- Includes role information for access control (admin, supervisor, enduser)
- Tracks verified status for email verification

#### Token Collection
- Stores refresh tokens for maintaining user sessions
- Includes expiration dates for security
- TTL index automatically removes expired tokens
- References user by userId

#### Verification Collection
- Supports multiple verification types (email, password reset)
- Stores verification tokens with expiration dates
- TTL index automatically removes expired verifications
- References user by userId

## API Structure

The API is organized into route modules, middleware, and services:

```mermaid
graph TB
    subgraph "Entry Point"
        App[app.ts]
    end
    
    subgraph "Routes"
        AuthRoutes[auth.routes.ts]
        ProtectedRoutes[protected.routes.ts]
        AdminRoutes[admin.routes.ts]
    end
    
    subgraph "Middleware"
        AuthMiddleware[auth.middleware.ts]
        ErrorHandler[error-handler.ts]
    end
    
    subgraph "Services"
        AuthService[auth.service.ts]
        TokenService[token.service.ts]
        EmailService[email.service.ts]
        PasswordService[password.service.ts]
    end
    
    subgraph "Models"
        UserModel[user.model.ts]
        TokenModel[token.model.ts]
        VerificationModel[verification.model.ts]
    end
    
    App --> AuthRoutes
    App --> ProtectedRoutes
    App --> AdminRoutes
    App --> ErrorHandler
    
    AuthRoutes --> AuthService
    AuthRoutes --> PasswordService
    ProtectedRoutes --> AuthMiddleware
    AdminRoutes --> AuthMiddleware
    
    AuthService --> TokenService
    AuthService --> EmailService
    AuthService --> UserModel
    AuthService --> VerificationModel
    
    TokenService --> TokenModel
    PasswordService --> UserModel
    PasswordService --> VerificationModel
    PasswordService --> EmailService
    
    AuthMiddleware --> TokenService
    
    classDef main fill:#4285F4,stroke:#0D47A1,color:white;
    classDef routes fill:#34A853,stroke:#0F9D58,color:white;
    classDef middleware fill:#FBBC05,stroke:#F57C00,color:black;
    classDef services fill:#EA4335,stroke:#B31412,color:white;
    classDef models fill:#9E9E9E,stroke:#616161,color:white;
    
    class App main
    class AuthRoutes,ProtectedRoutes,AdminRoutes routes
    class AuthMiddleware,ErrorHandler middleware
    class AuthService,TokenService,EmailService,PasswordService services
    class UserModel,TokenModel,VerificationModel models
```

### API Endpoints

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
| `/api/profile`                 | GET    | Get user profile                      | Authenticated     |
| `/api/profile`                 | PUT    | Update user profile                   | Authenticated     |
| `/api/change-password`         | POST   | Change password                       | Authenticated     |
| `/api/admin/users`             | GET    | Get all users                         | Admin             |
| `/api/admin/users/:id/role`    | PUT    | Update user role                      | Admin             |
| `/api/admin/reports`           | GET    | Access reports                        | Admin/Supervisor  |
| `/api/admin/dashboard`         | GET    | Access dashboard                      | Any Authenticated |

## Authentication Workflows

The system implements several authentication workflows:

### Registration and Email Verification

```mermaid
sequenceDiagram
    actor User
    participant API as API Server
    participant Auth as Auth Service
    participant DB as Database
    participant Email as Email Service
    
    User->>API: POST /auth/signup
    API->>Auth: signup(username, email, password)
    Auth->>DB: Check if user exists
    Auth->>DB: Create user (password hashed)
    Auth->>DB: Create verification record
    Auth->>Email: Send verification email
    Auth->>API: Return success response
    API->>User: 201 Created (userId)
    
    User->>API: POST /auth/verify-email (token)
    API->>Auth: verifyEmail(token)
    Auth->>DB: Find verification record
    Auth->>DB: Update user (isVerified = true)
    Auth->>DB: Delete verification record
    Auth->>API: Return success
    API->>User: 200 OK (Email verified)
```

### Login and Token Refresh

```mermaid
sequenceDiagram
    actor User
    participant API as API Server
    participant Auth as Auth Service
    participant Token as Token Service
    participant DB as Database
    
    User->>API: POST /auth/login
    API->>Auth: login(username, password)
    Auth->>DB: Find user
    Auth->>DB: Verify password
    Auth->>Token: Generate access token
    Auth->>Token: Generate refresh token
    Token->>DB: Store refresh token
    Auth->>API: Return tokens
    API->>User: 200 OK (accessToken, refreshToken)
    
    Note over User,API: Later when access token expires
    
    User->>API: POST /auth/refresh
    API->>Auth: refreshToken(refreshToken)
    Auth->>Token: Verify refresh token
    Token->>DB: Check token validity
    Auth->>Token: Generate new access token
    Auth->>API: Return new access token
    API->>User: 200 OK (accessToken)
```

### Password Reset Flow

```mermaid
sequenceDiagram
    actor User
    participant API as API Server
    participant Auth as Auth Service
    participant Password as Password Service
    participant DB as Database
    participant Email as Email Service
    
    User->>API: POST /auth/forgot-password
    API->>Password: generateResetToken(email)
    Password->>DB: Find user
    Password->>DB: Create reset token
    Password->>Email: Send password reset email
    Password->>API: Return success
    API->>User: 200 OK
    
    User->>API: POST /auth/reset-password
    API->>Password: resetPassword(token, newPassword)
    Password->>DB: Find reset token
    Password->>DB: Update user password (hashed)
    Password->>DB: Delete reset token
    Password->>API: Return success
    API->>User: 200 OK
```

## API Usage Steps

Here's a step-by-step guide for implementing authentication in a client application:

### User Registration Flow

```mermaid
graph TD
    A[Client App] -->|1. POST /auth/signup| B[API Server]
    B -->|2. Return userId| A
    A -->|3. Instruct user to check email| C[User]
    C -->|4. Get verification code from email| A
    A -->|5. POST /auth/verify-email| B
    B -->|6. Confirm verification| A
    A -->|7. Redirect to login| D[Login Screen]
```

### Authentication Flow

```mermaid
graph TD
    A[Client App] -->|1. POST /auth/login| B[API Server]
    B -->|2. Return tokens| A
    A -->|3. Store tokens| C[Local Storage/Cookies]
    A -->|4. Include token in headers| D[API Requests]
    D -->|"Authorization: Bearer {token}"| B
    
    E[Token Expired] -->|1. POST /auth/refresh| B
    B -->|2. New access token| A
    A -->|3. Update stored token| C
```

## Role-Based Access Control

The authentication system implements a comprehensive role-based access control (RBAC) model with three distinct user roles arranged in a hierarchical permission structure. This allows for fine-grained control over who can access which parts of the application.

### Role Hierarchy

The system enforces a strict role hierarchy where higher-level roles inherit all permissions from lower-level roles:

```mermaid
graph TD
    Admin[Admin Role]
    Supervisor[Supervisor Role]
    EndUser[End User Role]
    
    Admin -->|Inherits permissions from| Supervisor
    Supervisor -->|Inherits permissions from| EndUser
    
    classDef adminRole fill:#E53935,stroke:#C62828,color:white;
    classDef supervisorRole fill:#FB8C00,stroke:#EF6C00,color:white;
    classDef userRole fill:#43A047,stroke:#2E7D32,color:white;
    
    class Admin adminRole
    class Supervisor supervisorRole
    class EndUser userRole
```

### Role Definitions

1. **Admin Role (`UserRole.ADMIN`)**: 
   - System administrators with full access to all functionality
   - Can manage users, assign roles, and access all protected routes
   - Typically assigned to technical staff or organization leadership
   - Has access to user management and system configuration

2. **Supervisor Role (`UserRole.SUPERVISOR`)**: 
   - Mid-level access for team managers or supervisors
   - Can access reporting and monitoring features
   - Cannot modify user roles or access system configuration
   - Has all the permissions of regular end users plus additional oversight capabilities

3. **End User Role (`UserRole.ENDUSER`)**: 
   - Base level access for regular application users
   - Can manage their own profile and use basic application features
   - Cannot access administrative or supervisory functions
   - Default role assigned to all new users

### Route Access Patterns

The route access patterns demonstrate which roles can access which API endpoints:

```mermaid
graph TD
    subgraph "Admin Access"
        AdminUser[Admin User]
        AdminEndpoints[Admin-only Endpoints]
        
        AdminUser -->|Can access| AdminEndpoints
        
        subgraph "Admin-Only Routes"
            AR1[GET /api/admin/users]
            AR2[PUT /api/admin/users/:id/role]
        end
        
        AdminEndpoints --> AR1
        AdminEndpoints --> AR2
    end
    
    classDef adminRole fill:#E53935,stroke:#C62828,color:white;
    class AdminUser,AdminEndpoints,AR1,AR2 adminRole
```

```mermaid
graph TD
    subgraph "Supervisor Access"
        SupervisorUser[Supervisor User]
        AdminUser[Admin User]
        SupervisorEndpoints[Supervisor Endpoints]
        
        SupervisorUser -->|Can access| SupervisorEndpoints
        AdminUser -->|Can also access| SupervisorEndpoints
        
        subgraph "Supervisor Routes"
            SR1[GET /api/admin/reports]
        end
        
        SupervisorEndpoints --> SR1
    end
    
    classDef adminRole fill:#E53935,stroke:#C62828,color:white;
    classDef supervisorRole fill:#FB8C00,stroke:#EF6C00,color:white;
    
    class AdminUser adminRole
    class SupervisorUser,SupervisorEndpoints,SR1 supervisorRole
```

```mermaid
graph TD
    subgraph "End User Access"
        EndUser[End User]
        SupervisorUser[Supervisor User]
        AdminUser[Admin User]
        UserEndpoints[User Endpoints]
        
        EndUser -->|Can access| UserEndpoints
        SupervisorUser -->|Can also access| UserEndpoints
        AdminUser -->|Can also access| UserEndpoints
        
        subgraph "User Routes"
            UR1[GET /api/admin/dashboard]
            UR2[GET /api/profile]
            UR3[PUT /api/profile]
            UR4[POST /api/change-password]
        end
        
        UserEndpoints --> UR1
        UserEndpoints --> UR2
        UserEndpoints --> UR3
        UserEndpoints --> UR4
    end
    
    classDef adminRole fill:#E53935,stroke:#C62828,color:white;
    classDef supervisorRole fill:#FB8C00,stroke:#EF6C00,color:white;
    classDef userRole fill:#43A047,stroke:#2E7D32,color:white;
    
    class AdminUser adminRole
    class SupervisorUser supervisorRole
    class EndUser,UserEndpoints,UR1,UR2,UR3,UR4 userRole
```

### RBAC Implementation

The role-based access control is implemented through middleware functions in the `auth.middleware.ts` file:

1. **Authentication Middleware** (`authenticate`): 
   - Verifies JWT tokens for all protected routes
   - Attaches user information including role to the request object
   - Required for all protected endpoints

2. **Admin Check Middleware** (`requireAdmin`):
   - Ensures the authenticated user has the Admin role
   - Returns 403 Forbidden if a non-admin attempts to access an admin-only route

3. **Supervisor Check Middleware** (`requireSupervisor`):
   - Ensures the authenticated user has either Admin or Supervisor role
   - Returns 403 Forbidden if a regular user attempts to access a supervisor route

This middleware-based approach allows for clean route definitions with appropriate access restrictions:

```typescript
// Admin-only route example
router.get('/users', authenticate, requireAdmin, userController.getAllUsers);

// Supervisor route example
router.get('/reports', authenticate, requireSupervisor, reportController.getReports);

// Regular user route example
router.get('/profile', authenticate, userController.getProfile);
```

By enforcing role-based access at the route level through middleware, the system ensures that unauthorized users cannot access restricted functionality, even if they possess a valid authentication token.

## Testing Scope

The system implements comprehensive testing for authentication workflows:

```mermaid
graph LR
    subgraph "Testing Scope"
        AuthTest[Authentication Tests]
        RoleTest[Role-Based Access Tests]
        SecurityTest[Security Tests]
    end
    
    subgraph "Authentication Tests"
        A1[User Registration]
        A2[Email Verification]
        A3[User Login]
        A4[Token Refresh]
        A5[Password Reset]
        A6[Logout]
    end
    
    subgraph "Role-Based Access Tests"
        R1[Admin Access Tests]
        R2[Supervisor Access Tests]
        R3[User Access Tests]
        R4[Role Hierarchy Tests]
    end
    
    subgraph "Security Tests"
        S1[Input Validation]
        S2[Password Security]
        S3[Token Validation]
        S4[Rate Limiting]
    end
    
    AuthTest --> A1 & A2 & A3 & A4 & A5 & A6
    RoleTest --> R1 & R2 & R3 & R4
    SecurityTest --> S1 & S2 & S3 & S4
    
    classDef main fill:#4285F4,stroke:#0D47A1,color:white;
    classDef auth fill:#34A853,stroke:#0F9D58,color:white;
    classDef role fill:#FBBC05,stroke:#F57C00,color:black;
    classDef sec fill:#EA4335,stroke:#B31412,color:white;
    
    class AuthTest,RoleTest,SecurityTest main
    class A1,A2,A3,A4,A5,A6 auth
    class R1,R2,R3,R4 role
    class S1,S2,S3,S4 sec
```

### Testing Automation

The system provides both automated and interactive testing approaches:

```mermaid
flowchart TD
    Start[Start Tests] --> TestType{Test Type}
    
    TestType -->|Automated| Auto[Automated Tests]
    TestType -->|Interactive| Manual[Interactive Tests]
    
    Auto --> MailhogCheck{Use MailHog?}
    MailhogCheck -->|Yes| MailhogSetup[Setup MailHog]
    MailhogCheck -->|No| DBBypass[Database Token Access]
    
    MailhogSetup --> RunTests[Run Test Suite]
    DBBypass --> RunTests
    Manual --> Prompts[Configure User Prompts]
    Prompts --> RunTests
    
    RunTests --> Results[Test Results]
    Results --> CleanUp[Clean Up Test Data]
    CleanUp --> EndNode[End Tests]
    
    classDef startStyle fill:#4CAF50,stroke:#388E3C,color:white;
    classDef endStyle fill:#F44336,stroke:#D32F2F,color:white;
    classDef process fill:#2196F3,stroke:#1976D2,color:white;
    classDef decision fill:#FF9800,stroke:#F57C00,color:black;
    
    class Start startStyle
    class EndNode endStyle
    class RunTests,CleanUp,MailhogSetup,DBBypass,Prompts process
    class TestType,MailhogCheck decision
    class Results endStyle
```

## Security Considerations

The system implements several security measures:

1. **Password Security**: 
   - Passwords are hashed using bcrypt before storage
   - Password complexity requirements enforced

2. **Token Management**:
   - Short-lived access tokens (15 minutes by default)
   - Refresh tokens with secure rotation
   - Token storage in HTTP-only cookies as an option

3. **API Security**:
   - Rate limiting on authentication endpoints
   - CORS configuration
   - Helmet for HTTP header security

4. **Data Protection**:
   - Input validation
   - Prevention of user enumeration
   - Automatic cleanup of expired tokens and verification records

```mermaid
graph TD
    Auth[Authentication Security] --> PWD[Password Security]
    Auth --> Tokens[Token Security]
    Auth --> API[API Security]
    
    PWD --> P1[bcrypt Hashing]
    PWD --> P2[Password Complexity]
    PWD --> P3[Secure Reset]
    
    Tokens --> T1[Short-lived Tokens]
    Tokens --> T2[Secure Storage]
    Tokens --> T3[Refresh Mechanism]
    
    API --> A1[Rate Limiting]
    API --> A2[CORS Protection]
    API --> A3[HTTP Headers]
    API --> A4[Input Validation]
    
    classDef main fill:#673AB7,stroke:#512DA8,color:white;
    classDef pwdClass fill:#E53935,stroke:#C62828,color:white;
    classDef tokenClass fill:#43A047,stroke:#2E7D32,color:white;
    classDef apiClass fill:#FB8C00,stroke:#EF6C00,color:white;
    
    class Auth main
    class PWD,P1,P2,P3 pwdClass
    class Tokens,T1,T2,T3 tokenClass
    class API,A1,A2,A3,A4 apiClass
```

---

This technical documentation provides a comprehensive overview of the TypeScript Authentication System architecture, workflows, and testing methodology. For specific implementation details, refer to the source code and comments within individual files.