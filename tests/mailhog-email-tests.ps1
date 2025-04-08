#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tests the email functionality using MailHog API.

.DESCRIPTION
    This script performs comprehensive testing of the email functionality by 
    triggering application endpoints that send emails and then verifying receipt in MailHog.

.PARAMETER ApiBaseUrl
    The base URL of your application API. Default is http://localhost:3000.

.PARAMETER MailHogUrl
    The base URL of MailHog API. Default is http://localhost:8025.

.PARAMETER Verbose
    Run with detailed logging.

.EXAMPLE
    .\mailhog-email-tests.ps1

.EXAMPLE
    .\mailhog-email-tests.ps1 -ApiBaseUrl "http://localhost:8080" -Verbose

.NOTES
    Author: AuthSystem Team
    Date:   April 2025
#>

param (
    [string]$ApiBaseUrl = "http://localhost:3000",
    [string]$MailHogUrl = "http://localhost:8025",
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

# Function to clear all emails in MailHog
function Clear-MailHogEmails {
    try {
        Write-Verbose "Clearing all emails in MailHog"
        Invoke-RestMethod -Uri "$MailHogUrl/api/v1/messages" -Method Delete | Out-Null
        return $true
    }
    catch {
        Write-Warning "Failed to clear MailHog emails: $_"
        return $false
    }
}

# Function to wait for an email to arrive with specific text in subject or body
function Wait-ForEmail {
    param (
        [Parameter(Mandatory=$true)]
        [string]$SearchText,
        [int]$TimeoutSeconds = 10,
        [int]$PollIntervalSeconds = 1,
        [switch]$SearchInBody,
        [switch]$SearchInSubject
    )
    
    Write-Verbose "Waiting for email containing '$SearchText'"
    $startTime = Get-Date
    $endTime = $startTime.AddSeconds($TimeoutSeconds)
    
    while ((Get-Date) -lt $endTime) {
        try {
            $response = Invoke-RestMethod -Uri "$MailHogUrl/api/v2/messages" -Method Get
            
            foreach ($item in $response.items) {
                $subject = $item.Content.Headers.Subject[0]
                $body = $item.Content.Body
                
                $match = $false
                if ($SearchInSubject -and $subject -match $SearchText) {
                    $match = $true
                }
                if ($SearchInBody -and $body -match $SearchText) {
                    $match = $true
                }
                if (-not $SearchInSubject -and -not $SearchInBody) {
                    # If neither flag is specified, search in both
                    if ($subject -match $SearchText -or $body -match $SearchText) {
                        $match = $true
                    }
                }
                
                if ($match) {
                    return @{
                        Found = $true
                        Message = $item
                        Subject = $subject
                        Body = $body
                        Id = $item.ID
                    }
                }
            }
            
            # If we get here, no matching email was found yet
            Start-Sleep -Seconds $PollIntervalSeconds
        }
        catch {
            Write-Warning "Error checking for email: $_"
            Start-Sleep -Seconds $PollIntervalSeconds
        }
    }
    
    # If we get here, we timed out waiting for the email
    return @{
        Found = $false
        Error = "Email containing '$SearchText' not found after $TimeoutSeconds seconds"
    }
}

# Function to register a new user
function Register-NewUser {
    param (
        [string]$Email = "test_$(Get-Random)@example.com",
        [string]$Password = "Test1234!",
        [string]$Username = "testuser_$(Get-Random)"
    )
    
    $body = @{
        email = $Email
        password = $Password
        username = $Username
    } | ConvertTo-Json
    
    Write-Verbose "Registering new user: $Username <$Email>"
    
    try {
        $response = Invoke-RestMethod -Uri "$ApiBaseUrl/auth/signup" -Method Post -Body $body -ContentType "application/json"
        return @{
            Success = $true
            Email = $Email
            Password = $Password
            Username = $Username
            Response = $response
        }
    }
    catch {
        return @{
            Success = $false
            Error = "Failed to register user: $_"
        }
    }
}

# Function to request password reset
function Request-PasswordReset {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Email
    )
    
    $body = @{
        email = $Email
    } | ConvertTo-Json
    
    Write-Verbose "Requesting password reset for: $Email"
    
    try {
        $response = Invoke-RestMethod -Uri "$ApiBaseUrl/auth/forgot-password" -Method Post -Body $body -ContentType "application/json"
        return @{
            Success = $true
            Email = $Email
            Response = $response
        }
    }
    catch {
        return @{
            Success = $false
            Error = "Failed to request password reset: $_"
        }
    }
}

# Function to get verification token from email body
function Get-VerificationTokenFromEmail {
    param (
        [Parameter(Mandatory=$true)]
        [string]$EmailBody,
        [string]$Pattern = "token=([a-zA-Z0-9\-_]+)"
    )
    
    if ($EmailBody -match $Pattern) {
        return $matches[1]
    }
    
    return $null
}

# Function to verify email 
function Verify-Email {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Token
    )
    
    Write-Verbose "Verifying email with token: $Token"
    
    try {
        $response = Invoke-RestMethod -Uri "$ApiBaseUrl/auth/verify-email?token=$Token" -Method Get
        return @{
            Success = $true
            Response = $response
        }
    }
    catch {
        return @{
            Success = $false
            Error = "Failed to verify email: $_"
        }
    }
}

# Function to reset password
function Reset-Password {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Token,
        [string]$NewPassword = "NewPassword1234!"
    )
    
    $body = @{
        token = $Token
        password = $NewPassword
    } | ConvertTo-Json
    
    Write-Verbose "Resetting password with token: $Token"
    
    try {
        $response = Invoke-RestMethod -Uri "$ApiBaseUrl/auth/reset-password" -Method Post -Body $body -ContentType "application/json"
        return @{
            Success = $true
            NewPassword = $NewPassword
            Response = $response
        }
    }
    catch {
        return @{
            Success = $false
            Error = "Failed to reset password: $_"
        }
    }
}

# Main test function
function Test-EmailFunctionality {
    $errors = 0
    $totalTests = 0
    
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host "  EMAIL FUNCTIONALITY TESTS  " -ForegroundColor Cyan
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host "Starting tests at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    Write-Host "API URL: $ApiBaseUrl" -ForegroundColor Gray
    Write-Host "MailHog URL: $MailHogUrl" -ForegroundColor Gray
    
    # Clear all emails before starting tests
    Write-Host "`nClearing all existing emails..." -ForegroundColor Cyan
    Clear-MailHogEmails | Out-Null
    
    # Test 1: Registration Email Verification
    $totalTests++
    Write-Host "`n[$totalTests] Testing registration email verification..." -ForegroundColor Cyan
    
    # Register a new user
    $registerResult = Register-NewUser
    
    if (-not $registerResult.Success) {
        Write-Host "❌ Failed to register new user: $($registerResult.Error)" -ForegroundColor Red
        $errors++
    } else {
        Write-Host "✅ User registered successfully" -ForegroundColor Green
        
        # Wait for verification email
        $verificationEmail = Wait-ForEmail -SearchText $registerResult.Email -TimeoutSeconds 15 -SearchInBody
        
        if (-not $verificationEmail.Found) {
            Write-Host "❌ Verification email not received: $($verificationEmail.Error)" -ForegroundColor Red
            $errors++
        } else {
            Write-Host "✅ Verification email received" -ForegroundColor Green
            
            # Extract verification token
            $token = Get-VerificationTokenFromEmail -EmailBody $verificationEmail.Body
            
            if (-not $token) {
                Write-Host "❌ Could not extract verification token from email" -ForegroundColor Red
                $errors++
            } else {
                Write-Host "✅ Verification token extracted: $token" -ForegroundColor Green
                
                # Verify email
                $verifyResult = Verify-Email -Token $token
                
                if (-not $verifyResult.Success) {
                    Write-Host "❌ Failed to verify email: $($verifyResult.Error)" -ForegroundColor Red
                    $errors++
                } else {
                    Write-Host "✅ Email verified successfully" -ForegroundColor Green
                }
            }
        }
    }
    
    # Test 2: Password Reset Flow
    $totalTests++
    Write-Host "`n[$totalTests] Testing password reset flow..." -ForegroundColor Cyan
    
    # Clear emails from previous test
    Clear-MailHogEmails | Out-Null
    
    # Request password reset
    $resetRequestResult = Request-PasswordReset -Email $registerResult.Email
    
    if (-not $resetRequestResult.Success) {
        Write-Host "❌ Failed to request password reset: $($resetRequestResult.Error)" -ForegroundColor Red
        $errors++
    } else {
        Write-Host "✅ Password reset requested successfully" -ForegroundColor Green
        
        # Wait for password reset email
        $resetEmail = Wait-ForEmail -SearchText "reset" -TimeoutSeconds 15 -SearchInSubject
        
        if (-not $resetEmail.Found) {
            Write-Host "❌ Password reset email not received: $($resetEmail.Error)" -ForegroundColor Red
            $errors++
        } else {
            Write-Host "✅ Password reset email received" -ForegroundColor Green
            
            # Extract reset token
            $resetToken = Get-VerificationTokenFromEmail -EmailBody $resetEmail.Body
            
            if (-not $resetToken) {
                Write-Host "❌ Could not extract reset token from email" -ForegroundColor Red
                $errors++
            } else {
                Write-Host "✅ Reset token extracted: $resetToken" -ForegroundColor Green
                
                # Reset password
                $passwordResetResult = Reset-Password -Token $resetToken
                
                if (-not $passwordResetResult.Success) {
                    Write-Host "❌ Failed to reset password: $($passwordResetResult.Error)" -ForegroundColor Red
                    $errors++
                } else {
                    Write-Host "✅ Password reset successfully" -ForegroundColor Green
                }
            }
        }
    }
    
    # Print test summary
    Write-Host "`n====================================" -ForegroundColor Cyan
    Write-Host "  EMAIL TESTS SUMMARY  " -ForegroundColor Cyan
    Write-Host "====================================" -ForegroundColor Cyan
    
    if ($errors -eq 0) {
        Write-Host "✅ All $totalTests email tests passed successfully!" -ForegroundColor Green
    } else {
        Write-Host "❌ $errors out of $totalTests email tests failed!" -ForegroundColor Red
    }
    
    return @{
        TotalTests = $totalTests
        Errors = $errors
        Success = ($errors -eq 0)
    }
}

# Run the main test function
$result = Test-EmailFunctionality

# Return success/failure code
if ($result.Success) {
    exit 0
} else {
    exit 1
}