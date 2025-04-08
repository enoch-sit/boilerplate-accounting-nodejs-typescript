#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tests the MailHog SMTP and API service functionality.

.DESCRIPTION
    This script tests the MailHog service by sending a test email via SMTP
    and then retrieving it via the MailHog API. It verifies the email delivery pipeline.

.PARAMETER SmtpPort
    The SMTP port that MailHog is listening on. Default is 1025.

.PARAMETER ApiPort
    The API/Web port that MailHog is listening on. Default is 8025.

.PARAMETER BaseUrl
    The base URL where MailHog API is available. Default is http://localhost:8025.

.PARAMETER Verbose
    Run with detailed logging.

.EXAMPLE
    .\mailhog-check.ps1

.EXAMPLE
    .\mailhog-check.ps1 -Verbose

.NOTES
    Author: AuthSystem Team
    Date:   April 2025
#>

param (
    [int]$SmtpPort = 1025,
    [int]$ApiPort = 8025,
    [string]$BaseUrl = "http://localhost:8025",
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

# Function to check if MailHog API is accessible
function Test-MailHogApi {
    param (
        [string]$ApiUrl = "$BaseUrl/api/v2/messages"
    )
    
    try {
        Write-Verbose "Testing MailHog API at $ApiUrl"
        $response = Invoke-RestMethod -Uri $ApiUrl -Method Get -TimeoutSec 5
        return @{
            Available = $true
            Status = "MailHog API is accessible"
        }
    }
    catch {
        return @{
            Available = $false
            Status = "MailHog API is not accessible: $_"
        }
    }
}

# Function to send a test email via SMTP
function Send-TestEmail {
    param (
        [string]$SmtpServer = "localhost",
        [int]$Port = $SmtpPort,
        [string]$From = "test@example.com",
        [string]$To = "recipient@example.com",
        [string]$Subject = "Test Email $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        [string]$Body = "This is a test email sent by the MailHog check script at $(Get-Date)"
    )
    
    try {
        Write-Verbose "Sending test email via SMTP to $SmtpServer:$Port"
        
        # Generate a unique ID for tracking this email
        $uniqueId = [Guid]::NewGuid().ToString()
        $Subject = "$Subject - $uniqueId"
        
        # Create SMTP client object
        $smtpClient = New-Object System.Net.Mail.SmtpClient
        $smtpClient.Host = $SmtpServer
        $smtpClient.Port = $Port
        # No authentication needed for MailHog
        
        # Create mail message
        $mailMessage = New-Object System.Net.Mail.MailMessage
        $mailMessage.From = New-Object System.Net.Mail.MailAddress($From)
        $mailMessage.Subject = $Subject
        $mailMessage.Body = $Body
        $mailMessage.To.Add($To)
        
        # Send the message
        $smtpClient.Send($mailMessage)
        
        return @{
            Success = $true
            EmailId = $uniqueId
            Subject = $Subject
            From = $From
            To = $To
            SentAt = Get-Date
        }
    }
    catch {
        return @{
            Success = $false
            Error = "Failed to send email: $_"
        }
    }
}

# Function to check if the test email was received by MailHog
function Test-EmailReceived {
    param (
        [Parameter(Mandatory=$true)]
        [string]$SubjectPattern,
        [int]$MaxAttempts = 5,
        [int]$DelaySeconds = 2
    )
    
    Write-Verbose "Checking for email with subject matching: $SubjectPattern"
    
    # Attempt to find the email multiple times with delay
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            Write-Verbose "Attempt $attempt of $MaxAttempts"
            
            # Get all messages from MailHog API
            $response = Invoke-RestMethod -Uri "$BaseUrl/api/v2/messages" -Method Get
            
            # Look for our test email
            foreach ($item in $response.items) {
                $subject = $item.Content.Headers.Subject[0]
                Write-Verbose "Found email with subject: $subject"
                
                if ($subject -match $SubjectPattern) {
                    # Found our email
                    return @{
                        Found = $true
                        Message = $item
                        Subject = $subject
                        Body = $item.Content.Body
                        ReceivedAt = Get-Date
                    }
                }
            }
            
            # If we get here, the email wasn't found in this attempt
            Write-Verbose "Email not found on attempt $attempt, waiting $DelaySeconds seconds..."
            Start-Sleep -Seconds $DelaySeconds
        }
        catch {
            Write-Warning "Error checking for email: $_"
            Start-Sleep -Seconds $DelaySeconds
        }
    }
    
    # If we get here, we didn't find the email after all attempts
    return @{
        Found = $false
        Error = "Email with subject matching '$SubjectPattern' not found after $MaxAttempts attempts"
    }
}

# Function to clean up MailHog by deleting all messages
function Clear-MailHogMessages {
    try {
        Write-Verbose "Clearing all messages from MailHog"
        Invoke-RestMethod -Uri "$BaseUrl/api/v1/messages" -Method Delete | Out-Null
        return $true
    }
    catch {
        Write-Warning "Failed to clear MailHog messages: $_"
        return $false
    }
}

# Main testing function
function Test-MailHogFunctionality {
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host "  MAILHOG SERVICE CHECK  " -ForegroundColor Cyan
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host "Starting check at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    Write-Host "MailHog API URL: $BaseUrl" -ForegroundColor Gray
    Write-Host "MailHog SMTP Port: $SmtpPort" -ForegroundColor Gray
    
    # Step 1: Check if MailHog API is accessible
    Write-Host "`nChecking MailHog API accessibility..." -ForegroundColor Cyan
    $apiStatus = Test-MailHogApi
    
    if ($apiStatus.Available) {
        Write-Host "✅ MailHog API is accessible" -ForegroundColor Green
    } else {
        Write-Host "❌ MailHog API is NOT accessible: $($apiStatus.Status)" -ForegroundColor Red
        return @{
            Success = $false
            ApiAccessible = $false
            SmtpFunctional = $false
            Error = $apiStatus.Status
        }
    }
    
    # Step 2: Clear any existing messages
    Write-Host "`nClearing existing messages..." -ForegroundColor Cyan
    $clearResult = Clear-MailHogMessages
    
    if ($clearResult) {
        Write-Host "✅ Cleared existing messages" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Could not clear messages, test may not be reliable" -ForegroundColor Yellow
    }
    
    # Step 3: Send test email
    Write-Host "`nSending test email..." -ForegroundColor Cyan
    $sendResult = Send-TestEmail
    
    if ($sendResult.Success) {
        Write-Host "✅ Test email sent successfully" -ForegroundColor Green
        Write-Host "  Subject: $($sendResult.Subject)" -ForegroundColor Gray
        Write-Host "  From: $($sendResult.From)" -ForegroundColor Gray
        Write-Host "  To: $($sendResult.To)" -ForegroundColor Gray
    } else {
        Write-Host "❌ Failed to send test email: $($sendResult.Error)" -ForegroundColor Red
        return @{
            Success = $false
            ApiAccessible = $true
            SmtpFunctional = $false
            Error = $sendResult.Error
        }
    }
    
    # Step 4: Check if email was received
    Write-Host "`nChecking if test email was received..." -ForegroundColor Cyan
    $receiveResult = Test-EmailReceived -SubjectPattern $sendResult.EmailId
    
    if ($receiveResult.Found) {
        Write-Host "✅ Test email was received successfully" -ForegroundColor Green
        Write-Host "  Subject: $($receiveResult.Subject)" -ForegroundColor Gray
        Write-Host "  Body: $($receiveResult.Body)" -ForegroundColor Gray
    } else {
        Write-Host "❌ Test email was NOT received: $($receiveResult.Error)" -ForegroundColor Red
        return @{
            Success = $false
            ApiAccessible = $true
            SmtpFunctional = $false
            Error = $receiveResult.Error
        }
    }
    
    # Step 5: Test email deletion
    Write-Host "`nTesting email deletion functionality..." -ForegroundColor Cyan
    $deleteResult = Clear-MailHogMessages
    
    if ($deleteResult) {
        Write-Host "✅ Email deletion functionality works" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Email deletion functionality is unreliable" -ForegroundColor Yellow
    }
    
    # Overall success
    Write-Host "`n====================================" -ForegroundColor Cyan
    Write-Host "  MAILHOG TEST SUMMARY  " -ForegroundColor Cyan
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host "✅ MailHog is fully functional" -ForegroundColor Green
    Write-Host "✅ API is accessible" -ForegroundColor Green
    Write-Host "✅ SMTP functionality is working" -ForegroundColor Green
    Write-Host "`nEmail testing can proceed" -ForegroundColor Green
    
    return @{
        Success = $true
        ApiAccessible = $true
        SmtpFunctional = $true
    }
}

# Run the main test function
$result = Test-MailHogFunctionality

# Return the result object
return $result