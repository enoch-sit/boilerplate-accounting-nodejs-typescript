# JWT Token Design for Accounting System Updates

This guide explains how to extend and modify the JWT token system to accommodate new accounting roles, permissions, and features. It also covers how to use the migration scripts to update your database after making changes to the JWT token structure.

## Table of Contents

1. [JWT Token Structure Overview](#jwt-token-structure-overview)
2. [Adding New Roles for Accounting Functionality](#adding-new-roles-for-accounting-functionality)
3. [Extending JWT Token Payload with Custom Claims](#extending-jwt-token-payload-with-custom-claims)
4. [Using Migration Scripts](#using-migration-scripts)
5. [Testing Your JWT Token Changes](#testing-your-jwt-token-changes)
6. [Best Practices](#best-practices)

## JWT Background Information

### What is JWT?

JSON Web Token (JWT) is an open standard (RFC 7519) that defines a compact and self-contained way for securely transmitting information between parties as a JSON object. This information can be verified and trusted because it is digitally signed using a secret (with the HMAC algorithm) or a public/private key pair using RSA or ECDSA.

### JWT Structure

A JWT consists of three parts separated by dots (`.`):

1. **Header** - Contains metadata about the token type and the signing algorithm being used
2. **Payload** - Contains the claims (data) that are being transmitted
3. **Signature** - Used to verify the sender of the JWT and ensure the message wasn't changed along the way

Example JWT:

```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c
```

### How JWT Authentication Works

1. **User Login**: When a user logs in with valid credentials, the server creates a JWT token.
2. **Token Issuance**: The server signs the token with a secret key and sends it back to the client.
3. **Client Storage**: The client stores this token (usually in localStorage, sessionStorage, or a cookie).
4. **Subsequent Requests**: For each subsequent request, the client sends the token in the Authorization header.
5. **Token Verification**: The server verifies the token's signature using the secret key and extracts user information.
6. **Access Control**: The server grants or denies access based on the user information and permissions in the token.

### Key JWT Concepts

- **Stateless Authentication**: JWTs enable a stateless authentication model where the server doesn't need to store session data.
- **Claims**: Pieces of information asserted about a subject (like user ID, role, etc.)
  - **Registered Claims**: Predefined claims like "iss" (issuer), "exp" (expiration time), "sub" (subject)
  - **Public Claims**: Custom claims defined in a public registry
  - **Private Claims**: Custom claims specific to your application
- **Token Types**: Our system uses two types of tokens:
  - **Access Token**: Short-lived token used to access protected resources
  - **Refresh Token**: Longer-lived token used to obtain new access tokens without re-authentication

### Security Considerations

- **Token Expiration**: All tokens should have an expiration time to limit the damage if they're compromised.
- **Token Storage**: Tokens should be stored securely on the client side to prevent theft.
- **HTTPS**: Always use HTTPS to prevent token interception during transmission.
- **Secret Management**: JWT signing secrets must be kept secure and rotated periodically.

## JWT Token Structure Overview

The authentication system currently uses JSON Web Tokens (JWT) with the following structure:

### Token Payload Structure

```typescript
export interface TokenPayload {
  sub: string;          // User ID
  username: string;     // Username
  type: 'access' | 'refresh'; // Token type
  role: UserRole;       // User role (ADMIN, SUPERVISOR, USER)
}
```

### Current Roles

The system includes the following default roles:

- `ADMIN`: Highest role with full system access
- `SUPERVISOR`: Middle-level role with additional permissions
- `ENDUSER`: Regular user with standard permissions
- `USER`: Alias for ENDUSER, also representing regular users with standard permissions

## Adding New Roles for Accounting Functionality

To add new roles for accounting functionality, follow these steps:

### Step 1: Update the UserRole enum

Modify the `src/models/user.model.ts` file to include new accounting-related roles:

```typescript
export enum UserRole {
  USER = 'user',
  SUPERVISOR = 'supervisor',
  ADMIN = 'admin',
  // Add new accounting roles below
  ACCOUNTANT = 'accountant',
  FINANCE_MANAGER = 'finance_manager',
  AUDITOR = 'auditor'
}
```

### Step 2: Create Role-based Middleware

Create new middleware functions in `src/auth/auth.middleware.ts` for the new roles:

```typescript
/**
 * Middleware to restrict access to accountants, finance managers, and admins
 */
export const requireAccountant = (req: Request, res: Response, next: NextFunction) => {
  if (!req.user) {
    return res.status(401).json({ error: 'Authentication required' });
  }
  
  if (![UserRole.ACCOUNTANT, UserRole.FINANCE_MANAGER, UserRole.ADMIN].includes(req.user.role)) {
    return res.status(403).json({ error: 'Accountant access required' });
  }
  
  next();
};

/**
 * Middleware to restrict access to finance managers and admins
 */
export const requireFinanceManager = (req: Request, res: Response, next: NextFunction) => {
  if (!req.user) {
    return res.status(401).json({ error: 'Authentication required' });
  }
  
  if (![UserRole.FINANCE_MANAGER, UserRole.ADMIN].includes(req.user.role)) {
    return res.status(403).json({ error: 'Finance manager access required' });
  }
  
  next();
};
```

### Step 3: Create Routes for Each Role

Create new route files for accounting functionality with appropriate middleware:

```typescript
// src/routes/accounting.routes.ts
import { Router } from 'express';
import { authenticate, requireAccountant } from '../auth/auth.middleware';

const router = Router();

router.get('/transactions', authenticate, requireAccountant, (req, res) => {
  // Handle accounting transactions
});

// Add more accounting routes

export default router;
```

Remember to register these routes in your main `app.ts` file.

## Extending JWT Token Payload with Custom Claims

For more advanced accounting features, you might need to extend the JWT payload with custom claims.

### Step 1: Update TokenPayload Interface

Modify the `src/auth/token.service.ts` file to include additional fields:

```typescript
export interface TokenPayload {
  sub: string;
  username: string;
  type: 'access' | 'refresh';
  role: UserRole;
  // Add accounting-specific claims
  permissions?: string[];
  department?: string;
  costCenter?: string;
}
```

### Step 2: Include New Claims When Generating Tokens

Update the token generation logic to include the additional fields:

```typescript
// In token.service.ts
generateAccessToken(userId: string, username: string, role: UserRole, permissions: string[] = []): string {
  // ...existing code...
  
  const payload: TokenPayload = { 
    sub: userId, 
    username, 
    type: 'access', 
    role,
    permissions
  };
  
  // ...rest of the code...
}
```

### Step 3: Update Token Verification Logic

Make sure your token verification methods handle the new fields properly.

## Using Migration Scripts

After making changes to your JWT structure or user roles, you'll need to migrate your database. The project includes migration scripts to help with this process.

### Step 1: Create a Migration Plan

Before running any migration scripts, create a clear plan of the changes needed:

- Which users will have new roles?
- Will existing tokens need to be revoked?
- Do you need to update verification records?

### Step 2: Run the Migration Scripts

The project includes several migration scripts:

1. **Complete Migration**:

```bash
# Run all migration scripts in sequence
npx ts-node src/scripts/migrate-all.ts
```

2. **Individual Migrations**:

```bash
# Migrate only users (to update roles)
npx ts-node src/scripts/migrate-users.ts

# Migrate only tokens (to handle changes to token structure)
npx ts-node src/scripts/migrate-tokens.ts

# Migrate verification records
npx ts-node src/scripts/migrate-verifications.ts
```

### Step 3: Customize Migration Scripts

You may need to modify the migration scripts for your specific changes. For example, to update user roles:

```typescript
// In src/scripts/migrate-users.ts
async function migrateUsers() {
  try {
    // Connect to databases...
    
    const users = await OldUser.find({});
    
    for (const oldUser of users) {
      // Convert user data
      const userData = oldUser.toObject();
      
      // Apply role mapping for accounting upgrade
      if (userData.department === 'accounting') {
        userData.role = 'accountant';
      } else if (userData.title === 'Finance Manager') {
        userData.role = 'finance_manager';
      }
      
      // Create new user with updated role
      await NewUser.create(userData);
    }
    
    // Close connections...
  } catch (error) {
    // Handle errors...
  }
}
```

## Testing Your JWT Token Changes

After implementing changes to the JWT token structure or roles, thoroughly test your system.

### Test Access Control

```typescript
// Create a test file to verify role-based access
describe('Role-Based Access Control for Accounting', () => {
  test('should allow accountants to access transactions', async () => {
    // Create a token with accountant role
    const token = getTestToken('accountant');
    
    // Make a request to a protected endpoint
    const response = await request(app)
      .get('/api/accounting/transactions')
      .set('Authorization', `Bearer ${token}`);
      
    expect(response.status).toBe(200);
  });
  
  test('should deny regular users access to transactions', async () => {
    // Create a token with user role
    const token = getTestToken('user');
    
    // Make a request to a protected endpoint
    const response = await request(app)
      .get('/api/accounting/transactions')
      .set('Authorization', `Bearer ${token}`);
      
    expect(response.status).toBe(403);
  });
});
```

### Test Token Claims

Ensure your custom claims are properly included in tokens and verified.

## Best Practices

1. **Keep Tokens Small**: Only include necessary information in tokens to minimize size.
2. **Use Short Expiration Times**: Keep access tokens short-lived (15-30 minutes).
3. **Securely Store Secrets**: Keep your JWT secret keys secure and use different keys for development and production.
4. **Implement Token Revocation**: Use the refresh token mechanism to revoke tokens if needed.
5. **Regular Rotation**: Rotate JWT secrets periodically.
6. **Validate All Claims**: Always validate all claims before granting access.
7. **Include Only Necessary Information**: Don't include sensitive data in tokens.

## Example: Complete Accounting Role Implementation

Here's a complete example of implementing a new accounting role:

1. **Update UserRole enum**
2. **Create middleware**
3. **Add routes**
4. **Migrate existing users**
5. **Test access control**

By following this workflow, you can successfully extend the JWT token system for accounting functionality while maintaining security and proper access control.

Remember to run the migration scripts after making changes to ensure your database is up to date with the new structure.
