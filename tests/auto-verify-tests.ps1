# Improved script for testing authentication endpoints with automated email verification
# Change this URL if your service is running somewhere other than localhost:3000
$baseUrl = "http://localhost:3000"

# Create a directory to store temporary files
$testDir = ".\tests\curl-tests"
if (-not (Test-Path $testDir)) {
    New-Item -ItemType Directory -Path $testDir -Force
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
$resetToken = ""

# -----------------
# Auth Routes Tests
# -----------------

Write-Host "Starting Authentication API Tests with Automated Email Verification..." -ForegroundColor Magenta

# 1. Signup Test
$randomSuffix = Get-Random
$signupBody = @{
    username = "testuser$randomSuffix"
    email = "testuser$randomSuffix@example.com"
    password = "TestPassword123!"
} | ConvertTo-Json

Write-Host "Signing up user: $($signupBody | ConvertFrom-Json | Select-Object -ExpandProperty username)"
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/api/auth/signup" -Method Post -ContentType "application/json" -Body $signupBody -ErrorAction Stop
    Write-Host "Signup successful!" -ForegroundColor Green
    Write-Host "User ID: $($response.userId)"
    $userId = $response.userId
    
    # Save response to a file for reference
    $response | ConvertTo-Json | Out-File "$testDir\signup_response.json"
}
catch {
    Write-Host "Signup failed with error:" -ForegroundColor Red
    Write-Host $_.Exception.Message
    $_.Exception.Response
}

# 2. AUTOMATIC EMAIL VERIFICATION - Using the new testing route
if ($userId) {
    Write-Host "`nAutomating Email Verification..." -ForegroundColor Cyan
    
    # Method 1: Get the verification token through the API
    try {
        Write-Host "Retrieving verification token from API..." -ForegroundColor Yellow
        $tokenResponse = Invoke-RestMethod -Uri "$baseUrl/api/testing/verification-token/$userId" -Method Get -ErrorAction Stop
        $verificationToken = $tokenResponse.token
        
        if ($verificationToken) {
            Write-Host "Successfully retrieved verification token: $verificationToken" -ForegroundColor Green
            
            # Call the verify-email endpoint with the token
            $verifyBody = @{
                token = $verificationToken
            } | ConvertTo-Json
            
            Write-Host "`nVerifying email with token..."
            try {
                $verifyResponse = Invoke-RestMethod -Uri "$baseUrl/api/auth/verify-email" -Method Post -ContentType "application/json" -Body $verifyBody -ErrorAction Stop
                Write-Host "Email verification successful!" -ForegroundColor Green
                Write-Host "Message: $($verifyResponse.message)" -ForegroundColor Green
                
                # Save response for reference
                $verifyResponse | ConvertTo-Json | Out-File "$testDir\verify_email_response.json"
            }
            catch {
                Write-Host "Email verification failed with error:" -ForegroundColor Red
                Write-Host $_.Exception.Message
                
                # Method 2: Direct verification without token (fallback)
                Write-Host "`nFalling back to direct verification..." -ForegroundColor Yellow
                try {
                    $directVerifyResponse = Invoke-RestMethod -Uri "$baseUrl/api/testing/verify-user/$userId" -Method Post -ErrorAction Stop
                    Write-Host "Direct email verification successful!" -ForegroundColor Green
                    Write-Host "Message: $($directVerifyResponse.message)" -ForegroundColor Green
                    
                    # Save response for reference
                    $directVerifyResponse | ConvertTo-Json | Out-File "$testDir\direct_verify_email_response.json"
                }
                catch {
                    Write-Host "Direct email verification failed with error:" -ForegroundColor Red
                    Write-Host $_.Exception.Message
                    Write-Host "You may need to manually verify this user's email" -ForegroundColor Red
                }
            }
        }
    }
    catch {
        Write-Host "Failed to retrieve verification token: $($_.Exception.Message)" -ForegroundColor Red
        
        # Method 2: Direct verification without token (fallback)
        Write-Host "`nFalling back to direct verification..." -ForegroundColor Yellow
        try {
            $directVerifyResponse = Invoke-RestMethod -Uri "$baseUrl/api/testing/verify-user/$userId" -Method Post -ErrorAction Stop
            Write-Host "Direct email verification successful!" -ForegroundColor Green
            Write-Host "Message: $($directVerifyResponse.message)" -ForegroundColor Green
            
            # Save response for reference
            $directVerifyResponse | ConvertTo-Json | Out-File "$testDir\direct_verify_email_response.json"
        }
        catch {
            Write-Host "Direct email verification failed with error:" -ForegroundColor Red
            Write-Host $_.Exception.Message
            Write-Host "You may need to manually verify this user's email" -ForegroundColor Red
        }
    }
}

# 3. Login Test (should now work with verified email)
$loginBody = @{
    username = (($signupBody | ConvertFrom-Json).username)
    password = "TestPassword123!"
} | ConvertTo-Json

Write-Host "`nAttempting to login with verified account..."
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/api/auth/login" -Method Post -ContentType "application/json" -Body $loginBody -ErrorAction Stop
    Write-Host "Login successful!" -ForegroundColor Green
    
    # Save tokens
    $accessToken = $response.accessToken
    $refreshToken = $response.refreshToken
    
    # Save response for reference
    $response | ConvertTo-Json | Out-File "$testDir\login_response.json"
    
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
    $_.Exception.Response
}

# Continue with the rest of your authentication tests...
# -----------------
# 4. Protected Routes Tests
# -----------------

if ($accessToken) {
    Write-Host "`nTesting protected routes with authenticated user..." -ForegroundColor Cyan
    $headers = @{
        "Authorization" = "Bearer $accessToken"
    }
    
    # Dashboard access test
    try {
        $dashboardResponse = Invoke-RestMethod -Uri "$baseUrl/api/protected/dashboard" -Method Get -Headers $headers -ErrorAction Stop
        Write-Host "Protected dashboard access: SUCCESS" -ForegroundColor Green
        Write-Host "Message: $($dashboardResponse.message)" -ForegroundColor Green
    }
    catch {
        Write-Host "Protected dashboard access: FAILED" -ForegroundColor Red
        Write-Host $_.Exception.Message
    }
    
    # Profile access test
    try {
        $profileResponse = Invoke-RestMethod -Uri "$baseUrl/api/protected/profile" -Method Get -Headers $headers -ErrorAction Stop
        Write-Host "Profile access: SUCCESS" -ForegroundColor Green
    }
    catch {
        Write-Host "Profile access: FAILED" -ForegroundColor Red
        Write-Host $_.Exception.Message
    }
}
else {
    Write-Host "`nSkipping protected route tests as authentication failed" -ForegroundColor Red
}

Write-Host "`nAutomated authentication testing completed!" -ForegroundColor Magenta
Write-Host "Results saved to: $testDir"