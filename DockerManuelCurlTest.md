# Docker Manual Testing with Curl in PowerShell

This guide provides step-by-step instructions for manually testing each Docker container in the authentication system using curl commands in PowerShell.

## Table of Contents

1. [Environment Setup](#environment-setup)
2. [Development Environment Testing](#development-environment-testing)
   - [Auth Service Testing](#auth-service-testing)
   - [MongoDB Testing](#mongodb-testing)
   - [MailHog Testing](#mailhog-testing)
3. [MailHog Test Environment Testing](#mailhog-test-environment-testing)
4. [Troubleshooting](#troubleshooting)
5. [Advanced Testing Scenarios](#advanced-testing-scenarios)

## Environment Setup

Before running tests, you'll need to start the Docker containers:

### For Development Environment

```powershell
# Start the development environment
docker-compose -f docker-compose.dev.yml up -d

# Verify containers are running
docker ps
```

### For MailHog Testing Environment

```powershell
# Start the MailHog testing environment
docker-compose -f docker-compose.mailhog-test.yml up -d

# Verify containers are running
docker ps
```

## Development Environment Testing

The development environment runs the following services:

- Auth Service: <http://localhost:3000>
- MongoDB: localhost:27018
- MailHog: <http://localhost:8025> (UI) / localhost:1025 (SMTP)

### Auth Service Testing

#### 1. Health Check

```powershell
Invoke-RestMethod -Uri "http://localhost:3000/health" -Method Get
```

Expected response:

```json
{
  "status": "ok"
}
```

#### 2. User Registration

```powershell
$body = @{
    username = "testuser_$(Get-Random)"
    email = "testuser_$(Get-Random)@example.com"
    password = "TestPassword123!"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:3000/api/auth/signup" -Method Post -ContentType "application/json" -Body $body
```

This should return a response with userId and a message indicating that verification email was sent.

#### 3. Get Verification Token (Testing API)

Replace `USER_ID` with the userId from the previous response:

```powershell
$userId = "USER_ID"
$tokenResponse = Invoke-RestMethod -Uri "http://localhost:3000/api/testing/verification-token/$userId" -Method Get
$token = $tokenResponse.token
```

#### 4. Email Verification

```powershell
$verifyBody = @{
    token = $token
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:3000/api/auth/verify-email" -Method Post -ContentType "application/json" -Body $verifyBody
```

#### 5. User Login

```powershell
$loginBody = @{
    username = "YOUR_USERNAME"
    password = "TestPassword123!"
} | ConvertTo-Json

$loginResponse = Invoke-RestMethod -Uri "http://localhost:3000/api/auth/login" -Method Post -ContentType "application/json" -Body $loginBody

# Save tokens for later use
$accessToken = $loginResponse.accessToken
$refreshToken = $loginResponse.refreshToken
```

#### 6. Access Protected Route

```powershell
$headers = @{
    "Authorization" = "Bearer $accessToken"
}

Invoke-RestMethod -Uri "http://localhost:3000/api/protected/profile" -Method Get -Headers $headers
```

#### 7. Refresh Token

```powershell
$refreshBody = @{
    refreshToken = $refreshToken
} | ConvertTo-Json

$refreshResponse = Invoke-RestMethod -Uri "http://localhost:3000/api/auth/refresh" -Method Post -ContentType "application/json" -Body $refreshBody

# Update access token
$accessToken = $refreshResponse.accessToken
```

#### 8. Password Reset Flow

```powershell
# Request password reset
$forgotBody = @{
    email = "YOUR_EMAIL"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:3000/api/auth/forgot-password" -Method Post -ContentType "application/json" -Body $forgotBody

# Get reset token (testing API)
$resetTokenResponse = Invoke-RestMethod -Uri "http://localhost:3000/api/testing/password-reset-token/$userId" -Method Get
$resetToken = $resetTokenResponse.token

# Reset password
$resetBody = @{
    token = $resetToken
    newPassword = "NewPassword456!"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:3000/api/auth/reset-password" -Method Post -ContentType "application/json" -Body $resetBody
```

#### 9. Logout

```powershell
$logoutBody = @{
    refreshToken = $refreshToken
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:3000/api/auth/logout" -Method Post -ContentType "application/json" -Body $logoutBody
```

### MongoDB Testing

#### 1. Check MongoDB Connection

```powershell
# Install MongoDB PowerShell Module if you don't have it
# Install-Module -Name MongoDB

# Connect to MongoDB
$mongoUri = "mongodb://localhost:27018"
$client = [MongoDB.Driver.MongoClient]::new($mongoUri)
$database = $client.GetDatabase("auth_dev")
$collection = $database.GetCollection("users")
$users = $collection.Find($null).ToList()
Write-Output $users
```

Alternatively, use the mongo shell inside Docker:

```powershell
docker exec -it mongodb mongo --port 27017 auth_dev --eval "db.users.find()"
```

### MailHog Testing

#### 1. Check MailHog API

```powershell
Invoke-RestMethod -Uri "http://localhost:8025/api/v2/messages" -Method Get
```

#### 2. Send Test Email to MailHog

```powershell
$smtpServer = "localhost"
$smtpPort = 1025
$from = "test@example.com"
$to = "recipient@example.com"
$subject = "Test Email via PowerShell"
$body = "This is a test email sent from PowerShell to MailHog"

$smtpClient = New-Object System.Net.Mail.SmtpClient($smtpServer, $smtpPort)
$message = New-Object System.Net.Mail.MailMessage($from, $to, $subject, $body)
$smtpClient.Send($message)

# Verify email was received
Start-Sleep -Seconds 1
Invoke-RestMethod -Uri "http://localhost:8025/api/v2/messages" -Method Get
```

#### 3. Clear All Emails

```powershell
Invoke-RestMethod -Uri "http://localhost:8025/api/v1/messages" -Method Delete
```

## MailHog Test Environment Testing

The MailHog test environment runs services on different ports:

- Auth Service: <http://localhost:3001>
- MongoDB: localhost:27018 (same as dev)
- MailHog: <http://localhost:8026> (UI) / localhost:1026 (SMTP)

### 1. Auth Service Tests

```powershell
# Health Check
Invoke-RestMethod -Uri "http://localhost:3001/health" -Method Get
```

### 2. MailHog Tests

```powershell
# Check MailHog API
Invoke-RestMethod -Uri "http://localhost:8026/api/v2/messages" -Method Get

# Send Test Email
$smtpServer = "localhost"
$smtpPort = 1026
$from = "test@example.com"
$to = "recipient@example.com"
$subject = "Test Email via PowerShell to Test MailHog"
$body = "This is a test email sent from PowerShell to Test MailHog"

$smtpClient = New-Object System.Net.Mail.SmtpClient($smtpServer, $smtpPort)
$message = New-Object System.Net.Mail.MailMessage($from, $to, $subject, $body)
$smtpClient.Send($message)

# Verify
Start-Sleep -Seconds 1
Invoke-RestMethod -Uri "http://localhost:8026/api/v2/messages" -Method Get
```

## Troubleshooting

### Connection Refused Errors

```powershell
# Check if Docker containers are running
docker ps | Select-String "auth-service|mongodb|mailhog"

# Check Docker container logs
docker logs auth-service-dev
docker logs mongodb
docker logs mailhog

# Restart specific containers if needed
docker-compose -f docker-compose.dev.yml restart auth-service
```

### MailHog Not Receiving Emails

```powershell
# Verify SMTP port is open
Test-NetConnection -ComputerName localhost -Port 1025

# Check MailHog logs
docker logs mailhog

# Restart MailHog
docker-compose -f docker-compose.dev.yml restart mailhog
```

### MongoDB Connection Issues

```powershell
# Check if MongoDB is listening
Test-NetConnection -ComputerName localhost -Port 27018

# View MongoDB logs
docker logs mongodb

# Restart MongoDB container
docker-compose -f docker-compose.dev.yml restart mongodb
```

## Advanced Testing Scenarios

### Testing Complete Auth Flow with Script

Create a script to test the complete authentication flow:

```powershell
# 1. Register a user
$username = "testuser_$(Get-Random)"
$email = "testuser_$(Get-Random)@example.com"
$password = "TestPassword123!"

$body = @{
    username = $username
    email = $email
    password = $password
} | ConvertTo-Json

$signupResponse = Invoke-RestMethod -Uri "http://localhost:3000/api/auth/signup" -Method Post -ContentType "application/json" -Body $body
$userId = $signupResponse.userId

Write-Host "User registered with ID: $userId"

# 2. Get verification token
$tokenResponse = Invoke-RestMethod -Uri "http://localhost:3000/api/testing/verification-token/$userId" -Method Get
$token = $tokenResponse.token

Write-Host "Verification token: $token"

# 3. Verify email
$verifyBody = @{
    token = $token
} | ConvertTo-Json

$verifyResponse = Invoke-RestMethod -Uri "http://localhost:3000/api/auth/verify-email" -Method Post -ContentType "application/json" -Body $verifyBody
Write-Host "Email verified: $($verifyResponse.message)"

# 4. Login
$loginBody = @{
    username = $username
    password = $password
} | ConvertTo-Json

$loginResponse = Invoke-RestMethod -Uri "http://localhost:3000/api/auth/login" -Method Post -ContentType "application/json" -Body $loginBody
$accessToken = $loginResponse.accessToken
$refreshToken = $loginResponse.refreshToken

Write-Host "Login successful. Access token: $($accessToken.Substring(0, 20))..."

# 5. Access protected route
$headers = @{
    "Authorization" = "Bearer $accessToken"
}

$profileResponse = Invoke-RestMethod -Uri "http://localhost:3000/api/protected/profile" -Method Get -Headers $headers
Write-Host "Profile access successful: $($profileResponse.user.username)"

# 6. Logout
$logoutBody = @{
    refreshToken = $refreshToken
} | ConvertTo-Json

$logoutResponse = Invoke-RestMethod -Uri "http://localhost:3000/api/auth/logout" -Method Post -ContentType "application/json" -Body $logoutBody
Write-Host "Logout successful: $($logoutResponse.message)"
```

### Testing With Different User Roles

```powershell
# After login, update the user role in MongoDB
docker exec -it mongodb mongo --port 27017 auth_dev --eval 'db.users.updateOne({username: "YOUR_USERNAME"}, {$set: {role: "ADMIN"}})'

# Then test admin routes
$adminHeaders = @{
    "Authorization" = "Bearer $accessToken"
}

# Try accessing admin routes
Invoke-RestMethod -Uri "http://localhost:3000/api/admin/users" -Method Get -Headers $adminHeaders
```
