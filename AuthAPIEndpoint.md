# API Endpoints Documentation

This document provides a comprehensive reference for all API endpoints in the authentication system.

## Base URL

All endpoints are relative to the base URL: `http://localhost:3000` (development) or your deployed API URL.

## Authentication

Most endpoints require authentication using JWT tokens:

```http
Authorization: Bearer <access_token>
```

Access tokens expire after 15 minutes by default. Use the refresh token endpoint to obtain a new access token.

## Role-Based Access Control

The authentication system implements a hierarchical role-based access control (RBAC) system with four distinct user roles defined in `src/models/user.model.ts` (Lines 6-11):

### Role Constants and Hierarchy

```typescript
export enum UserRole {
  ADMIN = 'admin',        // Highest privilege level - full system access
  SUPERVISOR = 'supervisor', // Mid-level privilege - user management
  ENDUSER = 'enduser',    // Base level access - standard user operations
  USER = 'user'           // Alias for ENDUSER - backward compatibility
}
```

**Role Hierarchy (from highest to lowest privilege):**
1. **ADMIN** (`'admin'`) - Full system administration capabilities
2. **SUPERVISOR** (`'supervisor'`) - User management and oversight functions
3. **ENDUSER/USER** (`'enduser'`/`'user'`) - Standard authenticated user access

### Role Implementation Details

**Code Locations:**
- **Role Definition**: `src/models/user.model.ts` (Lines 6-11)
- **Role Middleware**: `src/auth/auth.middleware.ts` (Lines 89-116)
- **Role Assignment**: `quickCreateAdminPy/create_users.py` (Lines 18-50, 156)
- **Route Protection**: `src/routes/admin.routes.ts` (Multiple endpoints)

**Role Validation Process:**
1. JWT token contains user role in payload (`role` claim)
2. Authentication middleware extracts and validates role from token
3. Route-specific middleware checks required role permissions
4. Access granted/denied based on role hierarchy matching

### Endpoint Access Control Matrix

| Endpoint Category | ADMIN | SUPERVISOR | ENDUSER/USER | PUBLIC |
|------------------|-------|------------|--------------|---------|
| Auth Routes | ✓ | ✓ | ✓ | ✓ |
| Protected Routes | ✓ | ✓ | ✓ | ✗ |
| Admin Routes | ✓ | Limited | ✗ | ✗ |
| Testing Routes | ✓ | ✓ | ✓ | ✗ |

## Table of Contents

- [Role-Based Access Control](#role-based-access-control)
- [Auth Routes](#auth-routes)
- [Protected Routes](#protected-routes)
- [Admin Routes](#admin-routes)
- [Testing Routes](#testing-routes) (Development Only)
- [Miscellaneous Endpoints](#miscellaneous-endpoints)

---

## Auth Routes

Authentication and user management endpoints.

### Register a New User

```http
POST /api/auth/signup
```

**Description**: Creates a new user account and sends verification email.

**Access Level**: Public

**Request Body**:

```json
{
  "username": "string",
  "email": "string",
  "password": "string"
}
```

**Response (201 Created)**:

```json
{
  "message": "User registered successfully. Verification email has been sent.",
  "userId": "string"
}
```

**Possible Errors**:

- 400: Missing required fields
- 400: Username already exists
- 400: Email already exists
- 500: Registration failed

### Verify Email

```http
POST /api/auth/verify-email
```

**Description**: Verifies a user's email address with the token sent via email.

**Access Level**: Public

**Request Body**:

```json
{
  "token": "string"
}
```

**Response (200 OK)**:

```json
{
  "message": "Email verified successfully"
}
```

**Possible Errors**:

- 400: Token is required
- 400: Email verification failed
- 500: Email verification failed

### Resend Verification Code

```http
POST /api/auth/resend-verification
```

**Description**: Generates a new verification code and sends it to the specified email.

**Access Level**: Public

**Request Body**:

```json
{
  "email": "string"
}
```

**Response (200 OK)**:

```json
{
  "message": "Verification code resent"
}
```

**Possible Errors**:

- 400: Email is required
- 400: Failed to resend verification code
- 500: Failed to resend verification code

### Login

```http
POST /api/auth/login
```

**Description**: Authenticates user and returns access and refresh tokens.

**Access Level**: Public

**Request Body**:

```json
{
  "username": "string", 
  "password": "string"
}
```

**Response (200 OK)**:

```json
{
  "message": "Login successful",
  "accessToken": "string",
  "refreshToken": "string",
  "user": {
    "id": "string",
    "username": "string",
    "email": "string",
    "isVerified": boolean,
    "role": "string"
  }
}
```

**Possible Errors**:

- 400: Missing required fields
- 401: Invalid credentials
- 401: Email not verified
- 500: Login failed

### Refresh Token

```http
POST /api/auth/refresh
```

**Description**: Creates a new access token using a valid refresh token. This endpoint implements refresh token rotation for enhanced security - each successful refresh invalidates the old refresh token and returns a new one.

**Access Level**: Public

**Request Body**:

```json
{
  "refreshToken": "string"
}
```

**Response (200 OK)**:

```json
{
  "message": "Token refreshed successfully",
  "accessToken": "string",
  "refreshToken": "string"
}
```

**Possible Errors**:

- 400: Refresh token is required
- 401: Invalid refresh token
- 500: Token refresh failed

**Security Notes**:

- This endpoint implements **refresh token rotation** - the old refresh token is invalidated upon successful refresh
- A new refresh token is returned in the response and must be used for subsequent refresh operations
- The new refresh token is also set as an HTTP-only cookie for enhanced security
- If using the response JSON, make sure to store the new `refreshToken` value

### Logout

```http
POST /api/auth/logout
```

**Description**: Invalidates the current refresh token.

**Access Level**: Public

**Request Body**:

```json
{
  "refreshToken": "string"
}
```

**Response (200 OK)**:

```json
{
  "message": "Logout successful"
}
```

**Possible Errors**:

- 500: Logout failed

### Logout from All Devices

```
POST /api/auth/logout-all
```

**Description**: Invalidates all refresh tokens for the current user.

**Access Level**: Authenticated

**Headers**:

```
Authorization: Bearer <access_token>
```

**Response (200 OK)**:

```json
{
  "message": "Logged out from all devices"
}
```

**Possible Errors**:

- 401: Authentication required
- 500: Logout failed

### Request Password Reset

```
POST /api/auth/forgot-password
```

**Description**: Sends a password reset email to the specified address.

**Access Level**: Public

**Request Body**:

```json
{
  "email": "string"
}
```

**Response (200 OK)**:

```json
{
  "message": "If your email exists in our system, you will receive a password reset link"
}
```

### Reset Password

```
POST /api/auth/reset-password
```

**Description**: Resets a user's password using the token sent via email.

**Access Level**: Public

**Request Body**:

```json
{
  "token": "string",
  "newPassword": "string"
}
```

**Response (200 OK)**:

```json
{
  "message": "Password reset successful"
}
```

**Possible Errors**:

- 400: Token and new password are required
- 400: Password reset failed
- 500: Password reset failed

---

## Protected Routes

These routes require authentication via JWT access token.

### Get User Profile

```
GET /api/profile
```

**Description**: Returns the profile information of the authenticated user.

**Access Level**: Authenticated

**Headers**:

```
Authorization: Bearer <access_token>
```

**Response (200 OK)**:

```json
{
  "user": {
    "_id": "string",
    "username": "string",
    "email": "string",
    "isVerified": boolean,
    "role": "string",
    "createdAt": "date",
    "updatedAt": "date"
  }
}
```

**Possible Errors**:

- 401: Not authenticated
- 404: User not found
- 500: Failed to fetch profile

### Update User Profile

```
PUT /api/profile
```

**Description**: Updates the profile information of the authenticated user.

**Access Level**: Authenticated

**Headers**:

```
Authorization: Bearer <access_token>
```

**Request Body**:

```json
{
  "username": "string",
  "email": "string"
}
```

**Response (200 OK)**:

```json
{
  "user": {
    "_id": "string",
    "username": "string",
    "email": "string",
    "isVerified": boolean,
    "role": "string",
    "createdAt": "date",
    "updatedAt": "date"
  }
}
```

**Possible Errors**:

- 400: Username already taken
- 400: Email already taken
- 401: Not authenticated
- 404: User not found
- 500: Failed to update profile

### Change Password

```
POST /api/change-password
```

**Description**: Changes the password for the authenticated user.

**Access Level**: Authenticated

**Headers**:

```
Authorization: Bearer <access_token>
```

**Request Body**:

```json
{
  "currentPassword": "string",
  "newPassword": "string"
}
```

**Response (200 OK)**:

```json
{
  "message": "Password changed successfully"
}
```

**Possible Errors**:

- 400: Current password and new password are required
- 400: Current password is incorrect
- 401: Not authenticated
- 404: User not found
- 500: Failed to change password

### Access Dashboard

```
GET /api/dashboard
```

**Description**: Returns protected dashboard content for the authenticated user.

**Access Level**: Authenticated

**Headers**:

```
Authorization: Bearer <access_token>
```

**Response (200 OK)**:

```json
{
  "message": "This is protected content for your dashboard",
  "user": {
    "userId": "string",
    "username": "string",
    "role": "string"
  }
}
```

**Possible Errors**:

- 401: Authentication required

---

## Admin Routes

**Base Path**: `/api/admin`

**Global Access Control**: All admin routes require `ADMIN` role authentication
- **Middleware Chain**: `requireAuth` → `requireRole(UserRole.ADMIN)`
- **Implementation**: `src/routes/admin.routes.ts`
- **Role Validation**: Enforced via `src/auth/auth.middleware.ts` (Lines 89-116)

These routes require admin or supervisor privileges.

### Get All Users

```
GET /api/admin/users
```

**Description**: Returns a list of all users in the system.

**Access Level**: Admin Only (`UserRole.ADMIN`)

**Role-Based Access**:
- ✅ **ADMIN**: Full access to all users
- ❌ **SUPERVISOR**: Access denied
- ❌ **ENDUSER/USER**: Access denied

**Headers**:

```
Authorization: Bearer <access_token>
```

**Response (200 OK)**:

```json
{
  "users": [
    {
      "_id": "string",
      "username": "string",
      "email": "string",
      "isVerified": boolean,
      "role": "string",
      "createdAt": "date",
      "updatedAt": "date"
    }
  ]
}
```

**Possible Errors**:

- 401: Authentication required
- 403: Admin access required
- 500: Failed to fetch users

### Get User by ID

```http
GET /api/admin/users/:userId
```

**Description**: Returns user information for a specific user ID.

**Access Level**: Admin Only (`UserRole.ADMIN`)

**Role-Based Access**:
- ✅ **ADMIN**: Full access to user lookup
- ❌ **SUPERVISOR**: Access denied
- ❌ **ENDUSER/USER**: Access denied

**Implementation Status**: ✅ **IMPLEMENTED** - Available in current API version

**Headers**:

```
Authorization: Bearer <access_token>
```

**URL Parameters**:

- `userId`: The ID of the user to search for

**Response (200 OK)**:

```json
{
  "user": {
    "user_id": "string",
    "username": "string",
    "email": "string",
    "role": "string",
    "is_verified": boolean,
    "created_at": "date",
    "updated_at": "date"
  }
}
```

**Possible Errors**:

- 400: Invalid user ID format
- 401: Authentication required
- 403: Admin access required
- 404: User not found
- 500: Failed to fetch user

**Notes**:

- Returns 404 if user with specified ID doesn't exist.
- Response format is normalized for consistency with external services.

### Get User by Email

```
GET /api/admin/users/by-email/:email
```

**Description**: Returns user information for a specific email address. This endpoint is optimized for external integrations and Python scripts that need to look up users by email without fetching all users.

**Access Level**: Admin Only (`UserRole.ADMIN`)

**Role-Based Access**:
- ✅ **ADMIN**: Full access to user lookup
- ❌ **SUPERVISOR**: Access denied
- ❌ **ENDUSER/USER**: Access denied

**Implementation Status**: ✅ **IMPLEMENTED** - Available in current API version

**Headers**:

```
Authorization: Bearer <access_token>
```

**URL Parameters**:

- `email`: The email address to search for (URL encoded)

**Response (200 OK)**:

```json
{
  "user": {
    "_id": "string",
    "username": "string",
    "email": "string",
    "isVerified": boolean,
    "role": "string",
    "createdAt": "date",
    "updatedAt": "date"
  }
}
```

**Possible Errors**:

- 400: Email is required
- 401: Authentication required
- 403: Admin access required
- 404: User not found
- 500: Failed to fetch user

**Usage Examples**:

```bash
# Example URL (email should be URL encoded)
GET /api/admin/users/by-email/user%40example.com

# Python usage
response = await client.get(
    f"{auth_url}/api/admin/users/by-email/{urllib.parse.quote(email)}",
    headers={"Authorization": f"Bearer {admin_token}"}
)
```

**Notes**:

- Email parameter in URL must be properly URL encoded
- Returns 404 if user with specified email doesn't exist
- Optimized for single user lookup vs fetching all users
- Ideal for external API integrations and automation scripts

### Create a New User

```
POST /api/admin/users
```

**Description**: Creates a new user with specified role (admin can only create non-admin users).

**Access Level**: Admin

**Headers**:

```
Authorization: Bearer <access_token>
```

**Request Body**:

```json
{
  "username": "string",
  "email": "string",
  "password": "string",
  "role": "string", 
  "skipVerification": boolean
}
```

**Response (201 Created)**:

```json
{
  "message": "User created successfully",
  "userId": "string"
}
```

**Possible Errors**:

- 400: Missing required fields
- 400: Invalid role
- 401: Authentication required
- 403: Admin access required
- 403: Creating admin users is restricted
- 500: User creation failed

### Create Multiple Users in Batch

```
POST /api/admin/users/batch
```

**Description**: Creates multiple users at once and sends auto-generated passwords via email.

**Access Level**: Admin

**Headers**:

```
Authorization: Bearer <access_token>
```

**Request Body**:

```json
{
  "users": [
    {
      "username": "string",
      "email": "string",
      "role": "string" // Optional, defaults to "enduser"
    },
    {
      "username": "string",
      "email": "string",
      "role": "string" // Optional, defaults to "enduser"
    }
  ],
  "skipVerification": boolean // Optional, defaults to true
}
```

**Response (201 Created)**:

```json
{
  "message": "X of Y users created successfully",
  "results": [
    {
      "username": "string",
      "email": "string",
      "success": boolean,
      "message": "string",
      "userId": "string" // Only present if success is true
    }
  ],
  "summary": {
    "total": number,
    "successful": number,
    "failed": number
  }
}
```

**Possible Errors**:

- 400: A non-empty array of users is required
- 400: Each user must have a username and email
- 400: Invalid role provided
- 401: Authentication required
- 403: Admin access required
- 403: Creating admin users is restricted
- 500: Batch user creation failed

**Notes**:

- A secure random password is generated for each user
- Passwords are sent directly to users via email
- Failed user creations do not affect successful ones
- The response includes detailed results for each user

### Delete All Users

```
DELETE /api/admin/users
```

**Description**: Deletes all non-admin users from the system.

**Access Level**: Admin

**Headers**:

```
Authorization: Bearer <access_token>
```

**Request Body**:

```json
{
  "confirmDelete": "DELETE_ALL_USERS",
  "preserveAdmins": boolean
}
```

**Response (200 OK)**:

```json
{
  "message": "X users deleted successfully",
  "preservedAdmins": boolean
}
```

**Possible Errors**:

- 400: Confirmation required
- 401: Authentication required
- 403: Admin access required
- 500: Failed to delete users

### Delete a Specific User

```
DELETE /api/admin/users/:userId
```

**Description**: Deletes a specific user from the system.

**Access Level**: Admin

**Headers**:

```
Authorization: Bearer <access_token>
```

**URL Parameters**:

- `userId`: The ID of the user to delete

**Response (200 OK)**:

```json
{
  "message": "User deleted successfully",
  "user": {
    "username": "string",
    "email": "string",
    "role": "string"
  }
}
```

**Possible Errors**:

- 400: Cannot delete your own account
- 401: Authentication required
- 403: Admin access required
- 403: Cannot delete another admin user
- 404: User not found
- 500: Failed to delete user

### Update User Role

```
PUT /api/admin/users/:userId/role
```

**Description**: Updates the role of a specific user.

**Access Level**: Admin

**Headers**:

```
Authorization: Bearer <access_token>
```

**URL Parameters**:

- `userId`: The ID of the user to update

**Request Body**:

```json
{
  "role": "string"
}
```

**Response (200 OK)**:

```json
{
  "user": {
    "_id": "string",
    "username": "string",
    "email": "string",
    "isVerified": boolean,
    "role": "string",
    "createdAt": "date",
    "updatedAt": "date"
  }
}
```

**Possible Errors**:

- 400: Invalid role
- 401: Authentication required
- 403: Admin access required
- 404: User not found
- 500: Failed to update user role

### Access Reports

```
GET /api/admin/reports
```

**Description**: Returns reporting data for admin and supervisor users.

**Access Level**: Admin/Supervisor

**Headers**:

```
Authorization: Bearer <access_token>
```

**Response (200 OK)**:

```json
{
  "message": "Reports accessed successfully",
  "role": "string"
}
```

**Possible Errors**:

- 401: Authentication required
- 403: Supervisor access required

### Access Admin Dashboard

```
GET /api/admin/dashboard
```

**Description**: Returns dashboard content available to all authenticated users.

**Access Level**: Any Authenticated User

**Headers**:

```
Authorization: Bearer <access_token>
```

**Response (200 OK)**:

```json
{
  "message": "User dashboard accessed successfully",
  "role": "string"
}
```

**Possible Errors**:

- 401: Authentication required

### Reset User Password

```
POST /api/admin/users/:userId/reset-password
```

**Description**: Resets a user's password. Admins can either specify a new password or have the system generate a secure random password.

**Access Level**: Admin

**Headers**:

```
Authorization: Bearer <access_token>
```

**URL Parameters**:

- `userId`: The ID of the user whose password will be reset

**Request Body**:

```json
{
  "newPassword": "string",  // Required unless generateRandom is true
  "generateRandom": boolean // Optional, defaults to false
}
```

**Response (200 OK)**:

```json
{
  "message": "User password reset successfully",
  "user": {
    "username": "string",
    "email": "string"
  },
  "generatedPassword": "string" // Only included if generateRandom was true
}
```

**Possible Errors**:

- 400: New password is required unless generateRandom is true
- 401: Authentication required
- 403: Admin access required
- 404: User not found
- 500: Failed to reset user password

**Notes**:

- If `generateRandom` is set to true, the system will generate a secure random password
- The generated password is returned in the response, so the admin can provide it to the user
- If `generateRandom` is false, the `newPassword` field is required

---

## Testing Routes

These routes are only available in development mode.

### Get Verification Token

```
GET /api/testing/verification-token/:userId/:type?
```

**Description**: Returns the most recent verification token for a user (development only).

**Access Level**: Development

**URL Parameters**:

- `userId`: The ID of the user
- `type` (optional): The type of verification (default: EMAIL)

**Response (200 OK)**:

```json
{
  "token": "string",
  "expires": "date",
  "type": "string"
}
```

**Possible Errors**:

- 400: User ID is required
- 400: Invalid user ID format
- 404: No verification token found for this user
- 500: Failed to retrieve verification token

### Verify User Directly

```
POST /api/testing/verify-user/:userId
```

**Description**: Directly verifies a user's email without requiring the token (development only).

**Access Level**: Development

**URL Parameters**:

- `userId`: The ID of the user to verify

**Response (200 OK)**:

```json
{
  "message": "User email verified successfully",
  "user": {
    "id": "string",
    "username": "string",
    "email": "string",
    "isEmailVerified": boolean
  }
}
```

**Possible Errors**:

- 400: User ID is required
- 400: Invalid user ID format
- 404: User not found
- 500: Failed to verify user

---

## Miscellaneous Endpoints

### Health Check

```
GET /health
```

**Description**: Returns server health status.

**Access Level**: Public

**Response (200 OK)**:

```json
{
  "status": "ok"
}
```

## Response Status Codes

- `200 OK`: The request succeeded
- `201 Created`: Resource created successfully
- `400 Bad Request`: Invalid input data
- `401 Unauthorized`: Authentication required or failed
- `403 Forbidden`: Permission denied for the requested resource
- `404 Not Found`: Resource not found
- `500 Internal Server Error`: Server error
