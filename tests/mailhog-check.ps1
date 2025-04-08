#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tests MailHog service availability and functionality.

.DESCRIPTION
    This script checks if the MailHog service is running and accessible,
    and verifies that emails can be sent and retrieved through its API.

.EXAMPLE
    . .\mailhog-check.ps1
    $status = Test-MailhogService
    if ($status.Success) { Write-Host "MailHog is working properly" }

.NOTES
    Author: AuthSystem Team
    Date:   April 2025
#>

# Function to check if MailHog API is responding
function Test-MailhogApiAvailable {
    param (
        [string]$ApiUrl = "http://localhost:8025"
    )
    
    try {
        $response = Invoke-RestMethod -Uri "$ApiUrl/api/v2/messages" -Method Get -TimeoutSec 5
        return $true
    }
    catch {
        return $false
    }
}

# Function to clear all messages from MailHog
function Clear-MailhogMessages {
    param (
        [string]$ApiUrl = "http://localhost:8025"
    )
    
    try {
        Invoke-RestMethod -Uri "$ApiUrl/api/v1/messages" -Method Delete -TimeoutSec 5 | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

# Function to send a test email through SMTP to MailHog
function Send-TestEmail {
    param (
        [string]$SmtpServer = "localhost",
        [int]$SmtpPort = 1025,
        [string]$FromAddress = "test@example.com",
        [string]$ToAddress = "recipient@example.com",
        [string]$Subject = "Test Email from Pipeline",
        [string]$Body = "This is a test email sent by the testing pipeline."
    )
    
    try {
        # Create a .NET mail message
        $mail = New-Object System.Net.Mail.MailMessage
        $mail.From = New-Object System.Net.Mail.MailAddress($FromAddress)
        $mail.Subject = $Subject
        $mail.Body = $Body
        $mail.IsBodyHtml = $false
        $mail.To.Add($ToAddress)
        
        # Create SMTP client
        $smtp = New-Object System.Net.Mail.SmtpClient($SmtpServer, $SmtpPort)
        $smtp.EnableSsl = $false
        $smtp.Credentials = $null
        
        # Send the message
        $smtp.Send($mail)
        
        # Clean up
        $mail.Dispose()
        $smtp.Dispose()
        
        return $true
    }
    catch {
        Write-Verbose "Failed to send test email: $_"
        return $false
    }
}

# Function to check if a test email was received
function Test-EmailReceived {
    param (
        [string]$ApiUrl = "http://localhost:8025",
        [string]$FromAddress = "test@example.com",
        [string]$ToAddress = "recipient@example.com",
        [int]$RetryCount = 5,
        [int]$RetryDelay = 1 # seconds
    )
    
    for ($i = 0; $i -lt $RetryCount; $i++) {
        try {
            $messages = Invoke-RestMethod -Uri "$ApiUrl/api/v2/messages" -Method Get -TimeoutSec 5
            
            # Check if we have messages
            if ($messages.count -gt 0) {
                # Look for our test email
                foreach ($item in $messages.items) {
                    if (
                        ($item.Content.Headers.From -match $FromAddress) -and
                        ($item.Content.Headers.To -match $ToAddress)
                    ) {
                        return $true
                    }
                }
            }
            
            # Wait before retrying
            Start-Sleep -Seconds $RetryDelay
        }
        catch {
            Write-Verbose "Error checking for received email: $_"
            Start-Sleep -Seconds $RetryDelay
        }
    }
    
    return $false
}

# Main function to test MailHog service
function Test-MailhogService {
    param (
        [string]$ApiUrl = "http://localhost:8025",
        [string]$SmtpServer = "localhost",
        [int]$SmtpPort = 1025
    )
    
    # Step 1: Check if MailHog API is responding
    $apiAvailable = Test-MailhogApiAvailable -ApiUrl $ApiUrl
    if (-not $apiAvailable) {
        return @{
            Success = $false
            Message = "MailHog API is not available at $ApiUrl"
            ApiAvailable = $false
            CanSendEmail = $false
            CanReceiveEmail = $false
        }
    }
    
    # Step 2: Clear existing messages
    $clearSuccessful = Clear-MailhogMessages -ApiUrl $ApiUrl
    if (-not $clearSuccessful) {
        return @{
            Success = $false
            Message = "Failed to clear MailHog messages"
            ApiAvailable = $true
            CanSendEmail = $false
            CanReceiveEmail = $false
        }
    }
    
    # Step 3: Send a test email
    $fromAddress = "test-pipeline@example.com"
    $toAddress = "test-recipient@example.com"
    $subject = "Test Email from Pipeline - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    
    $sendSuccessful = Send-TestEmail `
        -SmtpServer $SmtpServer `
        -SmtpPort $SmtpPort `
        -FromAddress $fromAddress `
        -ToAddress $toAddress `
        -Subject $subject
    
    if (-not $sendSuccessful) {
        return @{
            Success = $false
            Message = "Failed to send test email to MailHog"
            ApiAvailable = $true
            CanSendEmail = $false
            CanReceiveEmail = $false
        }
    }
    
    # Step 4: Verify the email was received
    $emailReceived = Test-EmailReceived `
        -ApiUrl $ApiUrl `
        -FromAddress $fromAddress `
        -ToAddress $toAddress `
        -RetryCount 5 `
        -RetryDelay 1
    
    if (-not $emailReceived) {
        return @{
            Success = $false
            Message = "Test email was not received by MailHog"
            ApiAvailable = $true
            CanSendEmail = $true
            CanReceiveEmail = $false
        }
    }
    
    # All tests passed
    return @{
        Success = $true
        Message = "MailHog service is working properly"
        ApiAvailable = $true
        CanSendEmail = $true
        CanReceiveEmail = $true
    }
}

# If script is run directly (not sourced), run the test
if ($MyInvocation.InvocationName -eq $MyInvocation.MyCommand.Name) {
    $status = Test-MailhogService
    
    if ($status.Success) {
        Write-Host "✅ MailHog is working properly" -ForegroundColor Green
        Write-Host "  - API Available: Yes" -ForegroundColor Green
        Write-Host "  - Can Send Emails: Yes" -ForegroundColor Green
        Write-Host "  - Can Receive Emails: Yes" -ForegroundColor Green
        Write-Host "  - UI Available at: http://localhost:8025" -ForegroundColor Gray
    } else {
        Write-Host "❌ MailHog check failed: $($status.Message)" -ForegroundColor Red
        Write-Host "  - API Available: $(if ($status.ApiAvailable) {"Yes"} else {"No"})" -ForegroundColor $(if ($status.ApiAvailable) {"Green"} else {"Red"})
        Write-Host "  - Can Send Emails: $(if ($status.CanSendEmail) {"Yes"} else {"No"})" -ForegroundColor $(if ($status.CanSendEmail) {"Green"} else {"Red"})
        Write-Host "  - Can Receive Emails: $(if ($status.CanReceiveEmail) {"Yes"} else {"No"})" -ForegroundColor $(if ($status.CanReceiveEmail) {"Green"} else {"Red"})
    }
    
    exit [int](-not $status.Success)
}