# API Endpoints Documentation

This document provides a comprehensive reference for all API endpoints in the authentication system.

## Base URL

All endpoints are relative to the base URL: `http://localhost:3000` (development) or your deployed API URL.

## Authentication

Most endpoints require authentication using JWT tokens:

```
Authorization: Bearer <access_token>
```

Access tokens expire after 15 minutes by default. Use the refresh token endpoint to obtain a new access token.

## Table of Contents

- [Auth Routes](#auth-routes)
- [Protected Routes](#protected-routes)
- [Admin Routes](#admin-routes)
- [Testing Routes](#testing-routes) (Development Only)
- [Miscellaneous Endpoints](#miscellaneous-endpoints)

---

## Auth Routes

Authentication and user management endpoints.

### Register a New User

```
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

```
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

```
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

```
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

```
POST /api/auth/refresh
```

**Description**: Creates a new access token using a valid refresh token.

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
  "accessToken": "string"
}
```

**Possible Errors**:

- 400: Refresh token is required
- 401: Invalid refresh token
- 500: Token refresh failed

### Logout

```
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

These routes require admin or supervisor privileges.

### Get All Users

```
GET /api/admin/users
```

**Description**: Returns a list of all users in the system.

**Access Level**: Admin

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
