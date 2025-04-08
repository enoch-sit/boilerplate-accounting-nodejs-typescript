# Test script for authentication endpoints
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

Write-Host "Starting Authentication API Tests..." -ForegroundColor Magenta

# 1. Signup Test
$signupBody = @{
    username = "testuser$(Get-Random)"
    email = "testuser$(Get-Random)@example.com"
    password = "TestPassword123!"
} | ConvertTo-Json

Write-Host "Signing up user: $($signupBody.username)"
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

# We would need the verification token from email, which we can't get in this test
# For the purpose of testing, let's assume we have the token and continue with the flow

# 2. Login Test
$loginBody = @{
    username = (($signupBody | ConvertFrom-Json).username)
    password = "TestPassword123!"
} | ConvertTo-Json

Write-Host "`nAttempting to login..."
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/api/auth/login" -Method Post -ContentType "application/json" -Body $loginBody -ErrorAction Stop
    Write-Host "Login successful!" -ForegroundColor Green
    
    # Save tokens
    $accessToken = $response.accessToken
    $refreshToken = $response.refreshToken
    
    # Save response for reference
    $response | ConvertTo-Json | Out-File "$testDir\login_response.json"
}
catch {
    Write-Host "Login failed with error:" -ForegroundColor Red
    Write-Host $_.Exception.Message
    $_.Exception.Response
}

# 3. Refresh Token Test
if ($refreshToken) {
    $refreshBody = @{
        refreshToken = $refreshToken
    } | ConvertTo-Json
    
    Write-Host "`nAttempting to refresh token..."
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/auth/refresh" -Method Post -ContentType "application/json" -Body $refreshBody -ErrorAction Stop
        Write-Host "Token refresh successful!" -ForegroundColor Green
        $accessToken = $response.accessToken
        
        # Save response for reference
        $response | ConvertTo-Json | Out-File "$testDir\refresh_response.json"
    }
    catch {
        Write-Host "Token refresh failed with error:" -ForegroundColor Red
        Write-Host $_.Exception.Message
    }
}

# 4. Forgot Password Test
$emailBody = @{
    email = (($signupBody | ConvertFrom-Json).email)
} | ConvertTo-Json

Write-Host "`nTesting forgot password functionality..."
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/api/auth/forgot-password" -Method Post -ContentType "application/json" -Body $emailBody -ErrorAction Stop
    Write-Host "Forgot password request successful!" -ForegroundColor Green
    
    # Save response for reference
    $response | ConvertTo-Json | Out-File "$testDir\forgot_password_response.json"
}
catch {
    Write-Host "Forgot password request failed with error:" -ForegroundColor Red
    Write-Host $_.Exception.Message
}

# 5. Reset Password Test (would require the reset token from email)
# For testing purposes, assume we have a reset token
$resetToken = "sample-reset-token-that-would-come-from-email"
$resetPasswordBody = @{
    token = $resetToken
    newPassword = "NewPassword456!"
} | ConvertTo-Json

Write-Host "`nSimulating password reset (note: token would need to be real)..."
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/api/auth/reset-password" -Method Post -ContentType "application/json" -Body $resetPasswordBody -ErrorAction SilentlyContinue
    Write-Host "Password reset successful!" -ForegroundColor Green
}
catch {
    Write-Host "Password reset failed (expected with dummy token):" -ForegroundColor Yellow
    # This is expected to fail with a dummy token, so we handle it differently
}

# -----------------
# Protected Routes Tests (requires authentication)
# -----------------

Write-Host "`nStarting Protected Route Tests..." -ForegroundColor Magenta

if ($accessToken) {
    # 1. Get Profile Test
    Write-Host "`nAttempting to fetch user profile..."
    $headers = @{
        "Authorization" = "Bearer $accessToken"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/protected/profile" -Method Get -Headers $headers -ErrorAction Stop
        Write-Host "Profile fetch successful!" -ForegroundColor Green
        Write-Host "User: $($response.user | ConvertTo-Json)"
        
        # Save response for reference
        $response | ConvertTo-Json -Depth 4 | Out-File "$testDir\profile_response.json"
    }
    catch {
        Write-Host "Profile fetch failed with error:" -ForegroundColor Red
        Write-Host $_.Exception.Message
    }
    
    # 2. Update Profile Test
    $updateProfileBody = @{
        username = "updated_$(Get-Random)"
    } | ConvertTo-Json
    
    Write-Host "`nAttempting to update user profile..."
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/protected/profile" -Method Put -Headers $headers -Body $updateProfileBody -ContentType "application/json" -ErrorAction Stop
        Write-Host "Profile update successful!" -ForegroundColor Green
        Write-Host "Updated User: $($response.user | ConvertTo-Json)"
        
        # Save response for reference
        $response | ConvertTo-Json -Depth 4 | Out-File "$testDir\profile_update_response.json"
    }
    catch {
        Write-Host "Profile update failed with error:" -ForegroundColor Red
        Write-Host $_.Exception.Message
    }
    
    # 3. Change Password Test
    $changePasswordBody = @{
        currentPassword = "TestPassword123!"
        newPassword = "UpdatedPassword789!"
    } | ConvertTo-Json
    
    Write-Host "`nAttempting to change password..."
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/protected/change-password" -Method Post -Headers $headers -Body $changePasswordBody -ContentType "application/json" -ErrorAction Stop
        Write-Host "Password change successful!" -ForegroundColor Green
        
        # Save response for reference
        $response | ConvertTo-Json | Out-File "$testDir\change_password_response.json"
    }
    catch {
        Write-Host "Password change failed with error:" -ForegroundColor Red
        Write-Host $_.Exception.Message
    }
    
    # 4. Dashboard Access Test
    Write-Host "`nAttempting to access protected dashboard..."
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/protected/dashboard" -Method Get -Headers $headers -ErrorAction Stop
        Write-Host "Dashboard access successful!" -ForegroundColor Green
        Write-Host "Message: $($response.message)"
        
        # Save response for reference
        $response | ConvertTo-Json -Depth 4 | Out-File "$testDir\dashboard_response.json"
    }
    catch {
        Write-Host "Dashboard access failed with error:" -ForegroundColor Red
        Write-Host $_.Exception.Message
    }
}
else {
    Write-Host "Skipping protected route tests as no access token is available." -ForegroundColor Yellow
}

# -----------------
# Admin Routes Tests (requires admin access)
# -----------------

Write-Host "`nStarting Admin Route Tests..." -ForegroundColor Magenta
Write-Host "Note: These will likely fail unless the test user has admin privileges" -ForegroundColor Yellow

if ($accessToken) {
    $headers = @{
        "Authorization" = "Bearer $accessToken"
    }
    
    # 1. Get All Users Test
    Write-Host "`nAttempting to fetch all users (admin only)..."
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/admin/users" -Method Get -Headers $headers -ErrorAction SilentlyContinue
        Write-Host "Users fetch successful!" -ForegroundColor Green
        Write-Host "Number of users: $($response.users.Count)"
        
        # Save response for reference
        $response | ConvertTo-Json -Depth 4 | Out-File "$testDir\all_users_response.json"
    }
    catch {
        Write-Host "Users fetch failed with error (expected if not admin):" -ForegroundColor Yellow
        Write-Host $_.Exception.Message
    }
    
    # 2. Update User Role Test (would need a valid user ID)
    if ($userId) {
        $updateRoleBody = @{
            role = "USER"  # Assuming UserRole has values like USER, ADMIN, etc.
        } | ConvertTo-Json
        
        Write-Host "`nAttempting to update user role (admin only)..."
        try {
            $response = Invoke-RestMethod -Uri "$baseUrl/api/admin/users/$userId/role" -Method Put -Headers $headers -Body $updateRoleBody -ContentType "application/json" -ErrorAction SilentlyContinue
            Write-Host "Role update successful!" -ForegroundColor Green
            
            # Save response for reference
            $response | ConvertTo-Json -Depth 4 | Out-File "$testDir\role_update_response.json"
        }
        catch {
            Write-Host "Role update failed with error (expected if not admin):" -ForegroundColor Yellow
            Write-Host $_.Exception.Message
        }
    }
    
    # 3. Access Reports Test (supervisor access)
    Write-Host "`nAttempting to access reports (supervisor/admin only)..."
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/admin/reports" -Method Get -Headers $headers -ErrorAction SilentlyContinue
        Write-Host "Reports access successful!" -ForegroundColor Green
        Write-Host "Message: $($response.message)"
        
        # Save response for reference
        $response | ConvertTo-Json | Out-File "$testDir\reports_response.json"
    }
    catch {
        Write-Host "Reports access failed with error (expected if not supervisor/admin):" -ForegroundColor Yellow
        Write-Host $_.Exception.Message
    }
    
    # 4. Admin Dashboard Access Test
    Write-Host "`nAttempting to access admin dashboard..."
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/admin/dashboard" -Method Get -Headers $headers -ErrorAction SilentlyContinue
        Write-Host "Admin dashboard access successful!" -ForegroundColor Green
        Write-Host "Message: $($response.message)"
        
        # Save response for reference
        $response | ConvertTo-Json | Out-File "$testDir\admin_dashboard_response.json"
    }
    catch {
        Write-Host "Admin dashboard access failed with error:" -ForegroundColor Yellow
        Write-Host $_.Exception.Message
    }
}
else {
    Write-Host "Skipping admin route tests as no access token is available." -ForegroundColor Yellow
}

# -----------------
# Logout Tests
# -----------------

if ($refreshToken) {
    Write-Host "`nTesting logout functionality..." -ForegroundColor Magenta
    
    # 1. Logout Test
    $logoutBody = @{
        refreshToken = $refreshToken
    } | ConvertTo-Json
    
    Write-Host "`nAttempting to logout..."
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/auth/logout" -Method Post -ContentType "application/json" -Body $logoutBody -ErrorAction Stop
        Write-Host "Logout successful!" -ForegroundColor Green
        
        # Save response for reference
        $response | ConvertTo-Json | Out-File "$testDir\logout_response.json"
    }
    catch {
        Write-Host "Logout failed with error:" -ForegroundColor Red
        Write-Host $_.Exception.Message
    }
    
    # After logout, the refresh token should be invalid
    # We can test this with a token refresh attempt
    Write-Host "`nVerifying token invalidation after logout..."
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/auth/refresh" -Method Post -ContentType "application/json" -Body $logoutBody -ErrorAction SilentlyContinue
        Write-Host "Warning: Token refresh after logout still works!" -ForegroundColor Yellow
    }
    catch {
        Write-Host "Token refresh failed after logout (expected behavior)!" -ForegroundColor Green
    }
}

Write-Host "`nAll tests completed!" -ForegroundColor Magenta
Write-Host "Test results and responses saved to: $testDir"