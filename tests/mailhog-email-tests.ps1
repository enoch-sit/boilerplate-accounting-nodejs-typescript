# PowerShell script for testing authentication endpoints with MailHog email verification
# This script specifically tests the email verification flow using MailHog

# Base URLs for the authentication service and MailHog
$authBaseUrl = "http://localhost:3001" # Changed port for MailHog test environment
$mailhogBaseUrl = "http://localhost:8026" # MailHog web API port for test environment

# Create a directory to store test results
$testDir = ".\tests\mailhog-tests"
if (-not (Test-Path $testDir)) {
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null
}

# Function to display test results
function Show-TestResult {
    param (
        [string]$testName,
        [object]$response
    )
    Write-Host "`n======================="
    Write-Host "TEST: $testName" -ForegroundColor Cyan
    Write-Host "Status: $($response.StatusCode)" -ForegroundColor $(if ($response.StatusCode -lt 400) { "Green" } else { "Red" })
    Write-Host "Response:"
    Write-Host "$($response.Content)" -ForegroundColor $(if ($response.StatusCode -lt 400) { "Green" } else { "Yellow" })
    Write-Host "======================`n"
}

# Variables to store tokens and user data
$accessToken = ""
$refreshToken = ""
$userId = ""
$verificationToken = ""

# -----------------
# Helper Functions for MailHog Integration
# -----------------

function Get-MailhogMessages {
    try {
        $response = Invoke-RestMethod -Uri "$mailhogBaseUrl/api/v2/messages" -Method Get -ErrorAction Stop
        return $response
    }
    catch {
        Write-Host "Failed to retrieve messages from MailHog: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Clear-MailhogMessages {
    try {
        $response = Invoke-RestMethod -Uri "$mailhogBaseUrl/api/v1/messages" -Method Delete -ErrorAction Stop
        Write-Host "MailHog messages cleared successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to clear MailHog messages: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Extract-VerificationTokenFromEmail {
    param (
        [string]$emailTo
    )
    
    Write-Host "Waiting for verification email to arrive in MailHog..." -ForegroundColor Yellow
    
    # Wait for email to arrive (retry 10 times with 1-second delay)
    $retryCount = 0
    $maxRetries = 10
    $emailFound = $false
    $verificationUrl = $null
    
    while (-not $emailFound -and $retryCount -lt $maxRetries) {
        Start-Sleep -Seconds 1
        $messages = Get-MailhogMessages
        
        if ($messages -and $messages.items.length -gt 0) {
            foreach ($message in $messages.items) {
                # Check if this email is sent to our test user
                if ($message.to -like "*$emailTo*" -or $message.Content.Headers.To -like "*$emailTo*") {
                    $emailContent = $message.Content.Body
                    
                    # Extract verification URL using regex (pattern may need adjustment based on actual email format)
                    if ($emailContent -match "(https?://[^\s]+verify-email[^\s]+)") {
                        $verificationUrl = $matches[1]
                        $emailFound = $true
                        break
                    }
                    
                    # Alternative regex for token-only format
                    if ($emailContent -match "verification code: ([a-zA-Z0-9-]+)") {
                        $verificationToken = $matches[1]
                        $emailFound = $true
                        break
                    }
                }
            }
        }
        
        $retryCount++
    }
    
    if ($emailFound) {
        Write-Host "Verification email found!" -ForegroundColor Green
        
        # Extract token from URL if we have a URL
        if ($verificationUrl) {
            if ($verificationUrl -match "token=([^&]+)") {
                $verificationToken = $matches[1]
            }
        }
        
        return $verificationToken
    }
    else {
        Write-Host "Verification email not found after $maxRetries attempts" -ForegroundColor Red
        return $null
    }
}

# -----------------
# Email Verification Test Flow
# -----------------

Write-Host "Starting MailHog Email Verification Test..." -ForegroundColor Magenta

# Clear any existing messages in MailHog before starting
Clear-MailhogMessages

# 1. Signup Test
$randomSuffix = Get-Random
$testUsername = "testuser$randomSuffix"
$testEmail = "testuser$randomSuffix@example.com"
$testPassword = "TestPassword123!"

$signupBody = @{
    username = $testUsername
    email = $testEmail
    password = $testPassword
} | ConvertTo-Json

Write-Host "Signing up user: $testUsername"
try {
    $response = Invoke-RestMethod -Uri "$authBaseUrl/api/auth/signup" -Method Post -ContentType "application/json" -Body $signupBody -ErrorAction Stop
    Write-Host "Signup successful!" -ForegroundColor Green
    Write-Host "User ID: $($response.userId)"
    $userId = $response.userId
    
    # Save response to a file for reference
    $response | ConvertTo-Json | Out-File "$testDir\signup_response.json"
}
catch {
    Write-Host "Signup failed with error:" -ForegroundColor Red
    Write-Host $_.Exception.Message
    exit 1
}

# 2. Extract verification token from MailHog
if ($userId) {
    Write-Host "`nChecking MailHog for verification email..." -ForegroundColor Cyan
    
    $verificationToken = Extract-VerificationTokenFromEmail -emailTo $testEmail
    
    if ($verificationToken) {
        Write-Host "Successfully extracted verification token: $verificationToken" -ForegroundColor Green
        
        # Save MailHog data for debugging
        $mailhogData = Get-MailhogMessages
        $mailhogData | ConvertTo-Json -Depth 10 | Out-File "$testDir\mailhog_messages.json"
        
        # 3. Verify email with the token
        Write-Host "`nVerifying email with token from MailHog..."
        
        $verifyBody = @{
            token = $verificationToken
        } | ConvertTo-Json
        
        try {
            $verifyResponse = Invoke-RestMethod -Uri "$authBaseUrl/api/auth/verify-email" -Method Post -ContentType "application/json" -Body $verifyBody -ErrorAction Stop
            Write-Host "Email verification successful!" -ForegroundColor Green
            Write-Host "Message: $($verifyResponse.message)" -ForegroundColor Green
            
            # Save response for reference
            $verifyResponse | ConvertTo-Json | Out-File "$testDir\verify_email_response.json"
        }
        catch {
            Write-Host "Email verification failed with error:" -ForegroundColor Red
            Write-Host $_.Exception.Message
            exit 1
        }
    }
    else {
        Write-Host "Failed to extract verification token from MailHog" -ForegroundColor Red
        exit 1
    }
}

# 4. Login with verified account
Write-Host "`nAttempting to login with verified account..."
$loginBody = @{
    username = $testUsername
    password = $testPassword
} | ConvertTo-Json

try {
    $loginResponse = Invoke-RestMethod -Uri "$authBaseUrl/api/auth/login" -Method Post -ContentType "application/json" -Body $loginBody -ErrorAction Stop
    Write-Host "Login successful!" -ForegroundColor Green
    
    # Save tokens
    $accessToken = $loginResponse.accessToken
    $refreshToken = $loginResponse.refreshToken
    
    # Save response for reference
    $loginResponse | ConvertTo-Json | Out-File "$testDir\login_response.json"
    
    if ($accessToken) {
        Write-Host "Access token received successfully!" -ForegroundColor Green
    }
    if ($refreshToken) {
        Write-Host "Refresh token received successfully!" -ForegroundColor Green
    }
}
catch {
    Write-Host "Login failed with error:" -ForegroundColor Red
    Write-Host $_.Exception.Message
    exit 1
}

# 5. Access protected route with token
if ($accessToken) {
    Write-Host "`nTesting protected routes with authenticated user..." -ForegroundColor Cyan
    $headers = @{
        "Authorization" = "Bearer $accessToken"
    }
    
    try {
        $dashboardResponse = Invoke-RestMethod -Uri "$authBaseUrl/api/protected/dashboard" -Method Get -Headers $headers -ErrorAction Stop
        Write-Host "Protected dashboard access: SUCCESS" -ForegroundColor Green
        Write-Host "Message: $($dashboardResponse.message)" -ForegroundColor Green
        
        # Save response for reference
        $dashboardResponse | ConvertTo-Json | Out-File "$testDir\dashboard_response.json"
    }
    catch {
        Write-Host "Protected dashboard access: FAILED" -ForegroundColor Red
        Write-Host $_.Exception.Message
        exit 1
    }
}

# 6. Test password reset flow with MailHog
Write-Host "`nTesting password reset flow with MailHog..." -ForegroundColor Cyan

# Clear previous emails
Clear-MailhogMessages

# Request password reset
$forgotPasswordBody = @{
    email = $testEmail
} | ConvertTo-Json

try {
    $forgotResponse = Invoke-RestMethod -Uri "$authBaseUrl/api/auth/forgot-password" -Method Post -ContentType "application/json" -Body $forgotPasswordBody -ErrorAction Stop
    Write-Host "Password reset request successful!" -ForegroundColor Green
    
    # Save response for reference
    $forgotResponse | ConvertTo-Json | Out-File "$testDir\forgot_password_response.json"
}
catch {
    Write-Host "Password reset request failed with error:" -ForegroundColor Red
    Write-Host $_.Exception.Message
    exit 1
}

# Extract reset token from MailHog
$resetToken = Extract-VerificationTokenFromEmail -emailTo $testEmail

if ($resetToken) {
    Write-Host "Successfully extracted password reset token: $resetToken" -ForegroundColor Green
    
    # Reset password with token
    $newPassword = "NewPassword456!"
    $resetPasswordBody = @{
        token = $resetToken
        newPassword = $newPassword
    } | ConvertTo-Json
    
    try {
        $resetResponse = Invoke-RestMethod -Uri "$authBaseUrl/api/auth/reset-password" -Method Post -ContentType "application/json" -Body $resetPasswordBody -ErrorAction Stop
        Write-Host "Password reset successful!" -ForegroundColor Green
        
        # Save response for reference
        $resetResponse | ConvertTo-Json | Out-File "$testDir\reset_password_response.json"
        
        # Verify login with new password
        $loginNewPassBody = @{
            username = $testUsername
            password = $newPassword
        } | ConvertTo-Json
        
        try {
            $loginNewResponse = Invoke-RestMethod -Uri "$authBaseUrl/api/auth/login" -Method Post -ContentType "application/json" -Body $loginNewPassBody -ErrorAction Stop
            Write-Host "Login with new password successful!" -ForegroundColor Green
            
            # Save response for reference
            $loginNewResponse | ConvertTo-Json | Out-File "$testDir\login_new_password_response.json"
        }
        catch {
            Write-Host "Login with new password failed with error:" -ForegroundColor Red
            Write-Host $_.Exception.Message
        }
    }
    catch {
        Write-Host "Password reset failed with error:" -ForegroundColor Red
        Write-Host $_.Exception.Message
    }
}
else {
    Write-Host "Failed to extract password reset token from MailHog" -ForegroundColor Red
}

Write-Host "`nMailHog Email Verification Test Completed!" -ForegroundColor Magenta
Write-Host "Results saved to: $testDir"