#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tests authentication API endpoints using direct verification instead of email verification.

.DESCRIPTION
    This script tests the complete authentication flow including registration, email verification,
    login, token refresh, password reset, and protected route access using the testing API
    to bypass email verification when MailHog is not available.

.PARAMETER BaseUrl
    The base URL of the authentication API service.

.PARAMETER Verbose
    Run with extended logging.

.EXAMPLE
    .\auto-verify-tests.ps1

.EXAMPLE
    .\auto-verify-tests.ps1 -BaseUrl "http://localhost:4000" -Verbose

.NOTES
    Author: AuthSystem Team
    Date:   April 2025
#>

param (
    [string]$BaseUrl = "http://localhost:3000",
    [switch]$Verbose
)

# Configure error action and verbose preferences
if ($Verbose) {
    $VerbosePreference = "Continue"
    $ErrorActionPreference = "Continue"
} else {
    $VerbosePreference = "SilentlyContinue"
    $ErrorActionPreference = "Stop"
}

# Test user credentials
$testUser = @{
    Username = "testuser_$(Get-Random -Minimum 1000 -Maximum 9999)"
    Email = "test_$(Get-Random -Minimum 1000 -Maximum 9999)@example.com"
    Password = "TestPassword123!"
    NewPassword = "NewPassword456!"
}

# Variable to track test failures
$testFailures = 0

# Store test results
$testResults = @()
$testOutputDir = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "test-results/auto-verify"
if (-not (Test-Path $testOutputDir)) {
    New-Item -ItemType Directory -Path $testOutputDir -Force | Out-Null
}

# Function to format the output of API responses
function Format-Response {
    param (
        [object]$Response
    )
    
    if ($null -eq $Response) {
        return "No response received"
    }
    
    return ($Response | ConvertTo-Json -Depth 10)
}

# Function to test an API endpoint
function Test-ApiEndpoint {
    param (
        [string]$TestName,
        [string]$Endpoint,
        [string]$Method = "GET",
        [object]$Body = $null,
        [hashtable]$Headers = @{},
        [scriptblock]$ValidationScript = { $true }
    )
    
    Write-Host "`n=============================" -ForegroundColor Cyan
    Write-Host "Testing: $TestName" -ForegroundColor Cyan
    Write-Host "=============================" -ForegroundColor Cyan
    Write-Host "Endpoint: $Method $Endpoint" -ForegroundColor Gray
    
    if ($Body) {
        $bodyForDisplay = $Body | ConvertTo-Json -Compress
        Write-Host "Body: $bodyForDisplay" -ForegroundColor Gray
    }
    
    try {
        $params = @{
            Uri = "$BaseUrl$Endpoint"
            Method = $Method
            ContentType = "application/json"
            ErrorAction = "Stop"
        }
        
        if ($Body) {
            $params.Body = ($Body | ConvertTo-Json)
        }
        
        if ($Headers.Count -gt 0) {
            $params.Headers = $Headers
        }
        
        $startTime = Get-Date
        $response = Invoke-RestMethod @params
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalMilliseconds
        
        $formattedResponse = Format-Response -Response $response
        Write-Host "Response: $formattedResponse" -ForegroundColor Gray
        Write-Host "Duration: $($duration)ms" -ForegroundColor Gray
        
        # Save response to file
        $responseFileName = "$($TestName -replace '[ :]', '-').json"
        $responseFilePath = Join-Path $testOutputDir $responseFileName
        $response | ConvertTo-Json -Depth 10 | Out-File -FilePath $responseFilePath -Encoding utf8
        
        # Validate response using the provided script
        $validationResult = & $ValidationScript $response
        
        if ($validationResult -eq $true) {
            Write-Host "✅ Test Passed: $TestName" -ForegroundColor Green
            $testResults += @{
                Name = $TestName
                Endpoint = "$Method $Endpoint"
                Status = "Passed"
                Duration = $duration
                ResponseFile = $responseFileName
            }
            return @{
                Success = $true
                Response = $response
            }
        } else {
            Write-Host "❌ Test Failed: $TestName" -ForegroundColor Red
            Write-Host "   Reason: $validationResult" -ForegroundColor Red
            $global:testFailures++
            $testResults += @{
                Name = $TestName
                Endpoint = "$Method $Endpoint"
                Status = "Failed"
                Reason = $validationResult
                Duration = $duration
                ResponseFile = $responseFileName
            }
            return @{
                Success = $false
                Response = $response
                Error = $validationResult
            }
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
        Write-Host "❌ Test Failed: $TestName" -ForegroundColor Red
        Write-Host "   Error: $errorMessage" -ForegroundColor Red
        
        $global:testFailures++
        $testResults += @{
            Name = $TestName
            Endpoint = "$Method $Endpoint"
            Status = "Failed"
            Reason = $errorMessage
            Duration = 0
            ResponseFile = $null
        }
        
        return @{
            Success = $false
            Response = $null
            Error = $errorMessage
        }
    }
}

# Track start time
$startTime = Get-Date

# Header for test run
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  AUTHENTICATION API AUTO-VERIFICATION TEST SUITE  " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Base URL: $BaseUrl" -ForegroundColor Gray
Write-Host "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "Test User: $($testUser.Username) / $($testUser.Email)" -ForegroundColor Gray
Write-Host ""

# Store user data for tests
$userId = $null
$verificationToken = $null
$accessToken = $null
$refreshToken = $null
$passwordResetToken = $null

# Step 1: Test health endpoint
$healthResult = Test-ApiEndpoint `
    -TestName "Service Health Check" `
    -Endpoint "/health" `
    -Method "GET" `
    -ValidationScript {
        param($response)
        if ($response.status -eq "ok") {
            return $true
        }
        return "Expected status 'ok' but got '$($response.status)'"
    }

# Step 2: Test user registration
$registrationResult = Test-ApiEndpoint `
    -TestName "User Registration" `
    -Endpoint "/api/auth/signup" `
    -Method "POST" `
    -Body @{
        username = $testUser.Username
        email = $testUser.Email
        password = $testUser.Password
    } `
    -ValidationScript {
        param($response)
        if (-not $response.userId) {
            return "Response does not contain userId"
        }
        $script:userId = $response.userId
        return $true
    }

if ($registrationResult.Success) {
    # Step 3: Get verification token from testing API
    $verificationTokenResult = Test-ApiEndpoint `
        -TestName "Retrieve Verification Token" `
        -Endpoint "/api/testing/verification-token/$userId" `
        -Method "GET" `
        -ValidationScript {
            param($response)
            if (-not $response.token) {
                return "Response does not contain token"
            }
            $script:verificationToken = $response.token
            return $true
        }
    
    if ($verificationTokenResult.Success) {
        # Step 4: Verify email with token
        $verifyEmailResult = Test-ApiEndpoint `
            -TestName "Email Verification" `
            -Endpoint "/api/auth/verify-email" `
            -Method "POST" `
            -Body @{
                token = $verificationToken
            } `
            -ValidationScript {
                param($response)
                if (-not $response.message -or -not ($response.message -match "verified")) {
                    return "Expected verification success message"
                }
                return $true
            }
        
        # Step 5: Login with verified account
        $loginResult = Test-ApiEndpoint `
            -TestName "User Login" `
            -Endpoint "/api/auth/login" `
            -Method "POST" `
            -Body @{
                username = $testUser.Username
                password = $testUser.Password
            } `
            -ValidationScript {
                param($response)
                if (-not $response.accessToken -or -not $response.refreshToken) {
                    return "Response missing tokens"
                }
                $script:accessToken = $response.accessToken
                $script:refreshToken = $response.refreshToken
                return $true
            }
        
        if ($loginResult.Success) {
            # Step 6: Access a protected route
            $profileResult = Test-ApiEndpoint `
                -TestName "Access Protected Profile" `
                -Endpoint "/api/profile" `
                -Method "GET" `
                -Headers @{
                    "Authorization" = "Bearer $accessToken"
                } `
                -ValidationScript {
                    param($response)
                    if (-not $response.user -or $response.user.username -ne $testUser.Username) {
                        return "Invalid user profile data"
                    }
                    return $true
                }
            
            # Step 7: Refresh token
            $refreshResult = Test-ApiEndpoint `
                -TestName "Refresh Access Token" `
                -Endpoint "/api/auth/refresh" `
                -Method "POST" `
                -Body @{
                    refreshToken = $refreshToken
                } `
                -ValidationScript {
                    param($response)
                    if (-not $response.accessToken) {
                        return "No new access token received"
                    }
                    $script:accessToken = $response.accessToken
                    return $true
                }
            
            # Step 8: Request password reset
            $forgotPasswordResult = Test-ApiEndpoint `
                -TestName "Request Password Reset" `
                -Endpoint "/api/auth/forgot-password" `
                -Method "POST" `
                -Body @{
                    email = $testUser.Email
                } `
                -ValidationScript {
                    param($response)
                    if (-not $response.message -or -not ($response.message -match "sent")) {
                        return "Expected password reset email sent message"
                    }
                    return $true
                }
            
            if ($forgotPasswordResult.Success) {
                # Step 9: Get password reset token from testing API
                $resetTokenResult = Test-ApiEndpoint `
                    -TestName "Retrieve Password Reset Token" `
                    -Endpoint "/api/testing/password-reset-token/$userId" `
                    -Method "GET" `
                    -ValidationScript {
                        param($response)
                        if (-not $response.token) {
                            return "Response does not contain reset token"
                        }
                        $script:passwordResetToken = $response.token
                        return $true
                    }
                
                if ($resetTokenResult.Success) {
                    # Step 10: Reset password with token
                    $resetPasswordResult = Test-ApiEndpoint `
                        -TestName "Reset Password" `
                        -Endpoint "/api/auth/reset-password" `
                        -Method "POST" `
                        -Body @{
                            token = $passwordResetToken
                            newPassword = $testUser.NewPassword
                        } `
                        -ValidationScript {
                            param($response)
                            if (-not $response.message -or -not ($response.message -match "reset")) {
                                return "Expected password reset success message"
                            }
                            return $true
                        }
                    
                    # Step 11: Login with new password
                    $newLoginResult = Test-ApiEndpoint `
                        -TestName "Login with New Password" `
                        -Endpoint "/api/auth/login" `
                        -Method "POST" `
                        -Body @{
                            username = $testUser.Username
                            password = $testUser.NewPassword
                        } `
                        -ValidationScript {
                            param($response)
                            if (-not $response.accessToken) {
                                return "No access token received"
                            }
                            return $true
                        }
                }
            }
            
            # Step 12: Logout
            $logoutResult = Test-ApiEndpoint `
                -TestName "User Logout" `
                -Endpoint "/api/auth/logout" `
                -Method "POST" `
                -Body @{
                    refreshToken = $refreshToken
                } `
                -ValidationScript {
                    param($response)
                    if (-not $response.message -or -not ($response.message -match "logged out")) {
                        return "Expected logout success message"
                    }
                    return $true
                }
        }
    }
}

# Generate summary report
$endTime = Get-Date
$duration = ($endTime - $startTime).TotalSeconds

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "  TEST SUMMARY  " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Total Tests: $($testResults.Count)" -ForegroundColor White
Write-Host "Passed: $($testResults.Where({$_.Status -eq 'Passed'}).Count)" -ForegroundColor Green
Write-Host "Failed: $($testFailures)" -ForegroundColor $(if ($testFailures -gt 0) { "Red" } else { "Green" })
Write-Host "Duration: $($duration.ToString('0.00')) seconds" -ForegroundColor White
Write-Host "Test Results Directory: $testOutputDir" -ForegroundColor Gray

# Generate HTML report
$htmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>Auto Verification Test Results</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; }
        .summary { background-color: #f5f5f5; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { text-align: left; padding: 8px; border-bottom: 1px solid #ddd; }
        th { background-color: #f2f2f2; }
        tr:hover { background-color: #f5f5f5; }
        .passed { color: green; }
        .failed { color: red; }
        .header { display: flex; justify-content: space-between; align-items: center; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Auto Verification Test Results</h1>
        <div>$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</div>
    </div>
    
    <div class="summary">
        <h2>Summary</h2>
        <p>Base URL: $BaseUrl</p>
        <p>Total Tests: $($testResults.Count)</p>
        <p>Passed: <span class="passed">$($testResults.Where({$_.Status -eq 'Passed'}).Count)</span></p>
        <p>Failed: <span class="$(if ($testFailures -gt 0) { 'failed' } else { 'passed' })">$testFailures</span></p>
        <p>Duration: $($duration.ToString('0.00')) seconds</p>
        <p>Test User: $($testUser.Username) / $($testUser.Email)</p>
    </div>
    
    <h2>Test Details</h2>
    <table>
        <tr>
            <th>Test</th>
            <th>Endpoint</th>
            <th>Status</th>
            <th>Duration (ms)</th>
            <th>Details</th>
        </tr>
"@

foreach ($result in $testResults) {
    $statusClass = if ($result.Status -eq "Passed") { "passed" } else { "failed" }
    $htmlReport += @"
        <tr>
            <td>$($result.Name)</td>
            <td>$($result.Endpoint)</td>
            <td class="$statusClass">$($result.Status)</td>
            <td>$($result.Duration.ToString('0.00'))</td>
            <td>$(if ($result.Reason) { $result.Reason } else { "Response saved to $($result.ResponseFile)" })</td>
        </tr>
"@
}

$htmlReport += @"
    </table>
</body>
</html>
"@

# Save HTML report
$htmlReportPath = Join-Path $testOutputDir "auto-verify-report.html"
$htmlReport | Out-File -FilePath $htmlReportPath -Encoding utf8

Write-Host "HTML Report: $htmlReportPath" -ForegroundColor Gray
Write-Host "`nTests completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan

# Return exit code based on test success
exit [int]($testFailures -gt 0)