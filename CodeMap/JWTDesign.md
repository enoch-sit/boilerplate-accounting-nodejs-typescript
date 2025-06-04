# JWT Design Documentation

This document provides a comprehensive overview of the JWT (JSON Web Token) authentication design implemented in the Simple Accounting Authentication System.

## Table of Contents

- [JWT Design Documentation](#jwt-design-documentation)
  - [Table of Contents](#table-of-contents)
  - [JWT Structure](#jwt-structure)
    - [Header](#header)
    - [Payload](#payload)
    - [Signature](#signature)
  - [Token Types](#token-types)
  - [Authentication Flow](#authentication-flow)
  - [Token Lifecycle](#token-lifecycle)
  - [Role-Based Access Control](#role-based-access-control)
  - [Security Considerations](#security-considerations)
  - [Implementation Details](#implementation-details)
  - [Refresh Token Rotation](#refresh-token-rotation)
  - [Token Storage Strategy](#token-storage-strategy)

## JWT Structure

JSON Web Tokens (JWT) are compact, URL-safe tokens used for securely transmitting information between parties. Each JWT consists of three parts separated by dots (`.`):

```mermaid
graph TD
    JWT[JWT Token] --> Header[Header: Algorithm & Token Type]
    JWT --> Payload[Payload: Claims/Data]
    JWT --> Signature[Signature: Verification]
```

### Header

The header typically consists of two parts:
- **alg**: Algorithm used for signing (HS256 in our implementation)
- **typ**: Type of token (JWT)

Example header:
```json
{
  "alg": "HS256",
  "typ": "JWT"
}
```

### Payload

Our token payload contains the following standard and custom claims:

```mermaid
classDiagram
    class TokenPayload {
        +string sub
        +string username
        +string email
        +string type
        +UserRole role
    }
    
    class UserRole {
        ADMIN
        SUPERVISOR
        ENDUSER
        USER
    }

    TokenPayload --> UserRole
```

Example payload:
```json
{
  "sub": "user_id_12345",
  "username": "johndoe",
  "email": "john@example.com",
  "type": "access",
  "role": "admin",
  "iat": 1651052800,
  "exp": 1651053700
}
```

### Signature

The signature is created by combining the encoded header and payload with a secret key:

```
HMACSHA256(
  base64UrlEncode(header) + "." + base64UrlEncode(payload),
  secret
)
```

## Token Types

The system uses two types of tokens:

```mermaid
graph TD
    JWT[JWT Tokens] --> AccessToken[Access Token]
    JWT --> RefreshToken[Refresh Token]
    
    AccessToken --> |Short-lived| AP[Protected Resources Access]
    AccessToken --> |15min Default| AT[Authorization Header/Cookie]
    
    RefreshToken --> |Long-lived| RP[Get New Access Tokens]
    RefreshToken --> |7d Default| RT[Stored in Database]
```

1. **Access Token**
   - Short-lived (default: 15 minutes)
   - Used to access protected resources
   - Contains user identification and role information
   - Stateless - validity checked by signature verification only

2. **Refresh Token**
   - Longer-lived (default: 7 days)
   - Used to obtain new access tokens without re-authentication
   - Stored in database (MongoDB) for validation and revocation
   - Enables token revocation and security monitoring

## Authentication Flow

The flow for authentication using JWTs in the system:

```mermaid
sequenceDiagram
    participant Client
    participant AuthRoutes as Authentication Routes
    participant AuthService as Auth Service
    participant TokenService as Token Service
    participant Database as MongoDB
    
    Client->>AuthRoutes: POST /api/auth/login {username, password}
    AuthRoutes->>AuthService: Login(username, password)
    AuthService->>Database: Verify credentials
    Database-->>AuthService: User data
    
    AuthService->>TokenService: generateAccessToken(userId, username, email, role)
    TokenService-->>AuthService: Access token
    
    AuthService->>TokenService: generateRefreshToken(userId, username, email, role)
    TokenService->>Database: Store refresh token
    TokenService-->>AuthService: Refresh token
    
    AuthService-->>AuthRoutes: Tokens
    AuthRoutes-->>Client: Return tokens (HTTP-only cookies or response body)
    
    Note over Client,AuthRoutes: Later when accessing protected resources
    
    Client->>AuthRoutes: Request with access token
    AuthRoutes->>TokenService: verifyAccessToken(token)
    TokenService-->>AuthRoutes: Token valid/invalid
    Alt Token valid
        AuthRoutes-->>Client: Protected resource
    Else Token expired
        AuthRoutes-->>Client: 401 Unauthorized
        Client->>AuthRoutes: POST /api/auth/refresh with refresh token
        AuthRoutes->>TokenService: verifyRefreshToken(token)
        TokenService->>Database: Check if token exists and valid
        Database-->>TokenService: Token status
        TokenService-->>AuthRoutes: New access token
        AuthRoutes-->>Client: New access token
    End
```

## Token Lifecycle

```mermaid
stateDiagram-v2
    [*] --> Generated: User logs in
    Generated --> Active: Token issued
    Active --> Used: Token used for API request
    
    Active --> Expired: Time elapses
    Used --> Used: Multiple uses
    Used --> Expired: Time elapses
    
    state Active {
        [*] --> Valid
        Valid --> Valid: Successful verification
    }
    
    state Expired {
        [*] --> Invalid
        Invalid --> [*]: Access denied
    }
    
    Expired --> [*]: For Access Token
    Expired --> Refreshed: For Refresh Token
    Refreshed --> [*]: New Access Token
    
    state Refreshed {
        [*] --> NewAccessToken
    }
```

## Role-Based Access Control

JWT tokens include the user's role, which is used for role-based access control (RBAC):

```mermaid
graph TD
    JWT[JWT Token] --> Role[Contains Role]
    Role --> AuthMiddleware[Authentication Middleware]
    AuthMiddleware --> |Extracts role| RM[Role Middleware]
    
    RM --> |Admin| AdminRoutes[Admin Routes]
    RM --> |Supervisor| SupervisorRoutes[Supervisor Routes]
    RM --> |Any user| UserRoutes[User Routes]
    
    subgraph "Role Hierarchy"
    Admin[Admin]
    Supervisor[Supervisor]
    User[User/EndUser]
    
    Admin --> Supervisor
    Supervisor --> User
    end
```

## Security Considerations

```mermaid
mindmap
  root((JWT Security))
    Token Security
      Short-lived access tokens
      HTTP-only cookies
      Refresh token rotation
      HTTPS required
    Secret Management
      Environment variables
      Different keys for access/refresh
      Secure key storage
      Key rotation strategy
    Token Validation
      Signature verification
      Expiration check
      Token type verification
      Role validation
    Protection Against
      XSS
      CSRF
      Token theft
      Replay attacks
```

## Implementation Details

The JWT implementation is primarily contained in the TokenService class:

```mermaid
classDiagram
    class TokenService {
        +generateAccessToken(userId, username, email, role) string
        +generateRefreshToken(userId, username, email, role) Promise~string~
        +verifyAccessToken(token) TokenPayload|null
        +verifyRefreshToken(token) Promise~TokenPayload|null~
        +deleteRefreshToken(token) Promise~boolean~
        +deleteAllUserRefreshTokens(userId) Promise~boolean~
        +deleteAllRefreshTokens() Promise~number~
    }
    
    class TokenPayload {
        +string sub
        +string username
        +string email
        +string type
        +UserRole role
    }
    
    class Token {
        +ObjectId userId
        +string refreshToken
        +Date expires
        +Date createdAt
        +Date updatedAt
    }
    
    TokenService --> TokenPayload : creates/verifies
    TokenService --> Token : manages
```

## Refresh Token Rotation

The system implements a refresh token rotation mechanism to enhance security:

```mermaid
sequenceDiagram
    participant Client
    participant Auth as Auth Service
    participant Token as Token Service
    participant DB as Database
    
    Client->>Auth: POST /api/auth/refresh with refresh token
    Auth->>Token: verifyRefreshToken(token)
    Token->>DB: Validate token in database
    DB-->>Token: Token valid
    
    Token->>Token: Generate new access token
    Auth->>Token: deleteRefreshToken(oldToken)
    Token->>DB: Remove old refresh token
    DB-->>Token: Deletion confirmed
    
    Token->>Token: Generate new refresh token
    Token->>DB: Store new refresh token
    DB-->>Token: Storage confirmed
    
    Auth-->>Client: New access & refresh tokens
```

## Token Storage Strategy

```mermaid
flowchart TD
    A[JWT Token] --> B{Token Type}
    B -->|Access Token| C[Client Storage Options]
    B -->|Refresh Token| D[Server Storage]
    
    C --> C1[HTTP-only Cookie]
    C --> C2[Authorization Header]
    
    D --> D1[MongoDB]
    D1 --> D2[Token Collection]
    
    D2 --> E[Document Structure]
    E --> E1[userId: ObjectId]
    E --> E2[refreshToken: String]
    E --> E3[expires: Date]
    
    E --> F[Indexes]
    F --> F1[TTL Index on expires]