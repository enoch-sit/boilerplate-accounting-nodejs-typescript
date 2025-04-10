# JWT Authentication for Microservices: Implementation Guide

## Introduction

JSON Web Tokens (JWT) are a compact, URL-safe means of representing claims securely between two parties. This guide explains how to implement a shared JWT secret authentication system where:

- An authentication service runs on a separate server outside AWS
- A chatbot application runs on AWS
- Both services share only the JWT secret and validate the same access tokens

## Architecture Overview

```mermaid
flowchart TB
    subgraph "External Infrastructure"
        AuthService["Authentication Service"]
        Database[(User Database)]
    end
    
    subgraph "AWS Cloud"
        ALB["Application Load Balancer"]
        subgraph "ECS/EKS Cluster"
            ChatbotApp["Chatbot Application"]
        end
    end
    
    User(("User"))
    
    User --|1. Authentication Request|--> AuthService
    AuthService --|2. Query User Data|--> Database
    Database --|3. Return User Data|--> AuthService
    AuthService --|4. Issue JWT|--> User
    User --|5. Request with JWT|--> ALB
    ALB --|6. Forward Request with JWT|--> ChatbotApp
    ChatbotApp --|7. Validate JWT using Shared Secret|--> ChatbotApp
    ChatbotApp --|8. Response|--> User
    
    classDef aws fill:#FF9900,stroke:#232F3E,color:white;
    class ALB,ChatbotApp aws;
```

## JWT Components

A JWT consists of three parts separated by dots:
- **Header**: Contains token type and signing algorithm
- **Payload**: Contains claims (user data and metadata)
- **Signature**: Ensures the token hasn't been altered

Example JWT:
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c
```

## JWT Flow Sequence

```mermaid
sequenceDiagram
    participant User
    participant AuthService as Authentication Service
    participant ChatbotApp as Chatbot App (AWS)
    
    User->>AuthService: Login with credentials
    AuthService->>AuthService: Verify credentials
    AuthService->>AuthService: Generate JWT with shared secret
    AuthService->>User: Return JWT token
    
    User->>ChatbotApp: API request with JWT in header
    ChatbotApp->>ChatbotApp: Validate JWT using shared secret
    ChatbotApp->>ChatbotApp: Extract user info from claims
    ChatbotApp->>User: Process request and respond
    
    Note over AuthService,ChatbotApp: Both services know the same JWT secret
```

## Implementation Details

### 1. Authentication Service Setup (Non-AWS Server)

#### Key Components:
- **User Database**: Stores user credentials and profile information
- **Authentication API**: Validates credentials and issues JWTs
- **JWT Signing**: Uses the shared secret to sign tokens

#### Example Code (Node.js with Express):

```javascript
const express = require('express');
const jwt = require('jsonwebtoken');
const bodyParser = require('body-parser');

const app = express();
app.use(bodyParser.json());

// This JWT secret must be the same as used in the chatbot application
const JWT_SECRET = 'your-256-bit-secure-secret';
const JWT_EXPIRATION = '1h';

app.post('/login', (req, res) => {
  const { username, password } = req.body;
  
  // In production, replace with actual database lookup
  if (username === 'user' && password === 'password') {
    // User claims to include in the JWT
    const userClaims = {
      sub: '123456', // Subject (user ID)
      name: 'John Doe',
      role: 'user',
      iat: Math.floor(Date.now() / 1000) // Issued at timestamp
    };
    
    // Create the JWT
    const token = jwt.sign(
      userClaims,
      JWT_SECRET,
      { expiresIn: JWT_EXPIRATION }
    );
    
    // Return the token to the client
    res.json({ token });
  } else {
    res.status(401).json({ error: 'Invalid credentials' });
  }
});

app.listen(3000, () => {
  console.log('Authentication service running on port 3000');
});
```

### 2. AWS Chatbot Application Setup

#### Deployment Components:
- **Container Definition**: Define Docker container for the chatbot
- **Task Definition**: ECS/EKS configuration for the container
- **Service Definition**: Deployment settings for the chatbot
- **Environment Variables**: Configure the shared JWT secret securely

#### Secret Management:
- Store the JWT secret in AWS Secrets Manager or Parameter Store
- Inject the secret into the container as an environment variable

#### Example Code (Node.js Chatbot with Express):

```javascript
const express = require('express');
const jwt = require('jsonwebtoken');
const app = express();

// Get JWT secret from environment variable
// In production, use AWS Secrets Manager or Parameter Store
const JWT_SECRET = process.env.JWT_SECRET;

// Middleware to validate JWT
const authenticateJWT = (req, res, next) => {
  const authHeader = req.headers.authorization;
  
  if (!authHeader) {
    return res.status(401).json({ error: 'Authorization header missing' });
  }
  
  // Extract the token (assumes Bearer token format)
  const token = authHeader.split(' ')[1];
  
  try {
    // Verify the token using the shared secret
    const user = jwt.verify(token, JWT_SECRET);
    req.user = user; // Attach user information to the request
    next();
  } catch (error) {
    return res.status(403).json({ error: 'Invalid or expired token' });
  }
};

// Protected chatbot endpoint
app.post('/api/chat', authenticateJWT, (req, res) => {
  // The user is authenticated, access user info via req.user
  const { message } = req.body;
  const userId = req.user.sub;
  const userName = req.user.name;
  
  // Process the chat message...
  const response = `Hello ${userName}, your message was: ${message}`;
  
  res.json({ response });
});

app.listen(8080, () => {
  console.log('Chatbot API running on port 8080');
});
```

## Security Considerations

```mermaid
graph TD
    A[JWT Security Considerations]
    A --> B[Secret Management]
    A --> C[Token Validation]
    A --> D[Token Expiration]
    A --> E[Transport Security]
    
    B --> B1[Use AWS Secrets Manager]
    B --> B2[Rotate secrets regularly]
    B --> B3[Minimum 256-bit key length]
    
    C --> C1[Verify signature]
    C --> C2[Validate claims]
    C --> C3[Check token not revoked]
    
    D --> D1[Short-lived tokens]
    D --> D2[Implement refresh tokens]
    
    E --> E1[Always use HTTPS]
    E --> E2[Secure headers]
```

### Secret Management
1. **Secret Storage**: 
   - Store the JWT secret in AWS Secrets Manager
   - Never hardcode the secret in your application
   - Use IAM roles to control access to the secret

2. **Secret Rotation**:
   - Implement a rotation strategy for the JWT secret
   - Coordinate rotation between both services
   - Consider using a grace period for old tokens during rotation

### Token Security
1. **Token Lifetime**:
   - Use short expiration times (15-60 minutes)
   - Implement refresh token strategy for longer sessions
   - Include standard claims like "exp" (expiration time)

2. **Claims Validation**:
   - Validate audience ("aud") if applicable
   - Check issuer ("iss") to ensure the token came from your auth service
   - Verify the token hasn't expired

## AWS Deployment Guide

### 1. Store JWT Secret in AWS Secrets Manager

```bash
# Create the secret using AWS CLI
aws secretsmanager create-secret \
    --name "jwt/shared-secret" \
    --description "JWT shared secret for authentication" \
    --secret-string "{\"JWT_SECRET\":\"your-256-bit-secure-secret\"}"
```

### 2. Create ECS Task Definition with Secret

```json
{
  "family": "chatbot-task",
  "networkMode": "awsvpc",
  "executionRoleArn": "arn:aws:iam::123456789012:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::123456789012:role/chatbotServiceRole",
  "containerDefinitions": [
    {
      "name": "chatbot-container",
      "image": "123456789012.dkr.ecr.us-west-2.amazonaws.com/chatbot:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8080,
          "hostPort": 8080,
          "protocol": "tcp"
        }
      ],
      "secrets": [
        {
          "name": "JWT_SECRET",
          "valueFrom": "arn:aws:secretsmanager:us-west-2:123456789012:secret:jwt/shared-secret:JWT_SECRET::"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/chatbot",
          "awslogs-region": "us-west-2",
          "awslogs-stream-prefix": "chatbot"
        }
      }
    }
  ],
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512"
}
```

### 3. IAM Policies

Create a policy that allows access to the secret:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:us-west-2:123456789012:secret:jwt/shared-secret-*"
    }
  ]
}
```

Attach this policy to your ECS task execution role.

## Conclusion

This implementation provides a secure authentication system with these benefits:

1. **Separation of Concerns**: Authentication logic is isolated from the application
2. **Scalability**: Both services can scale independently
3. **Security**: Minimal shared information (only the JWT secret)
4. **Statelessness**: No session state needs to be maintained

Remember that JWT secrets are highly sensitive. Always follow best practices for secret management, use proper key lengths, and implement a robust rotation strategy for your production environment.
