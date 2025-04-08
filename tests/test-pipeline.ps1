#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Comprehensive testing pipeline for Windows development environments.

.DESCRIPTION
    This script runs a complete testing pipeline for the authentication system, including:
    - Unit tests
    - Docker environment verification
    - MailHog functionality testing
    - API endpoint testing with and without email verification

.PARAMETER UnitTestsOnly
    Run only the unit tests

.PARAMETER ApiTestsOnly
    Run only the API endpoint tests

.PARAMETER SkipDockerChecks
    Skip Docker environment verification

.PARAMETER CiMode
    Run in CI/CD mode with appropriate settings for automated environments

.PARAMETER Verbose
    Run with extended logging

.EXAMPLE
    .\test-pipeline.ps1

.EXAMPLE
    .\test-pipeline.ps1 -UnitTestsOnly

.EXAMPLE
    .\test-pipeline.ps1 -ApiTestsOnly -SkipDockerChecks

.NOTES
    Author: AuthSystem Team
    Date:   April 2025
#>

param (
    [switch]$UnitTestsOnly,
    [switch]$ApiTestsOnly,
    [switch]$SkipDockerChecks,
    [switch]$CiMode,
    [switch]$Verbose
)

# Set ErrorActionPreference based on verbose mode
if ($Verbose) {
    $ErrorActionPreference = "Continue"
    $VerbosePreference = "Continue"
} else {
    $ErrorActionPreference = "Stop"
    $VerbosePreference = "SilentlyContinue"
}

# Script locations
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$dockerHealthCheck = Join-Path $scriptDir "docker-health-check.ps1"
$mailhogCheck = Join-Path $scriptDir "mailhog-check.ps1"

# Application URLs
$appBaseUrl = "http://localhost:3000"
$mailhogApiUrl = "http://localhost:8025"

# Set up test results directory
$testResultsDir = Join-Path $scriptDir "test-results"
if (-not (Test-Path $testResultsDir)) {
    New-Item -ItemType Directory -Path $testResultsDir | Out-Null
}

# Start timer for overall pipeline execution
$pipelineTimer = [System.Diagnostics.Stopwatch]::StartNew()

#region Helper Functions
function Write-StepHeader {
    param (
        [string]$Message
    )
    
    Write-Host "`n===============================================" -ForegroundColor Cyan
    Write-Host "  $Message" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
}

function Write-StepResult {
    param (
        [string]$StepName,
        [bool]$Success,
        [string]$Details = ""
    )
    
    if ($Success) {
        Write-Host "✅ $StepName - " -ForegroundColor Green -NoNewline
        Write-Host "PASSED" -ForegroundColor Green
    } else {
        Write-Host "❌ $StepName - " -ForegroundColor Red -NoNewline
        Write-Host "FAILED" -ForegroundColor Red
        if ($Details) {
            Write-Host "   Details: $Details" -ForegroundColor Yellow
        }
    }
}

function Test-ApiEndpoint {
    param (
        [string]$Endpoint,
        [string]$Method = "GET",
        [object]$Body = $null,
        [hashtable]$Headers = @{}
    )
    
    try {
        $params = @{
            Uri = "$appBaseUrl$Endpoint"
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
        
        $response = Invoke-RestMethod @params
        return @{
            Success = $true
            Response = $response
        }
    }
    catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
            Response = $null
        }
    }
}
#endregion

#region Main Pipeline Execution
Write-StepHeader "Starting Authentication System Testing Pipeline"
Write-Host "Time: $(Get-Date)" -ForegroundColor Gray
Write-Host "Mode: $(if($UnitTestsOnly){'Unit Tests Only'} elseif($ApiTestsOnly){'API Tests Only'} else {'Full Pipeline'})" -ForegroundColor Gray

# Step 1: Check if we're running the right Node.js version
Write-StepHeader "Checking Node.js Environment"
try {
    $nodeVersion = node -v
    $npmVersion = npm -v
    Write-Host "Node.js Version: $nodeVersion" -ForegroundColor Green
    Write-Host "NPM Version: $npmVersion" -ForegroundColor Green
    
    # Check if node version is 18+
    if ($nodeVersion -match 'v(\d+)' -and [int]$matches[1] -ge 18) {
        Write-StepResult -StepName "Node.js Version Check" -Success $true
    } else {
        Write-StepResult -StepName "Node.js Version Check" -Success $false -Details "Node.js v18+ is required"
    }
}
catch {
    Write-StepResult -StepName "Node.js Environment" -Success $false -Details $_.Exception.Message
    if (-not $CiMode) {
        Write-Host "Ensure Node.js is installed and in your PATH" -ForegroundColor Yellow
        exit 1
    }
}

# Step 2: Docker Environment Check (unless skipped)
$dockerAvailable = $true
if (-not $SkipDockerChecks) {
    Write-StepHeader "Checking Docker Environment"
    try {
        # Source the Docker health check script
        . $dockerHealthCheck
        
        # Run the Docker health check
        $dockerStatus = Test-DockerEnvironment
        
        if ($dockerStatus.Success) {
            Write-StepResult -StepName "Docker Environment" -Success $true
            foreach ($container in $dockerStatus.Containers) {
                Write-Host "  - $($container.Name): " -NoNewline
                if ($container.Running) {
                    Write-Host "Running" -ForegroundColor Green
                } else {
                    Write-Host "Stopped" -ForegroundColor Red
                    $dockerAvailable = $false
                }
            }
        } else {
            Write-StepResult -StepName "Docker Environment" -Success $false -Details $dockerStatus.Message
            $dockerAvailable = $false
        }
    }
    catch {
        Write-StepResult -StepName "Docker Environment" -Success $false -Details $_.Exception.Message
        $dockerAvailable = $false
    }
}

# Step 3: MailHog Check (if Docker is available and not skipped)
$mailhogAvailable = $false
if ($dockerAvailable -and -not $SkipDockerChecks -and -not $UnitTestsOnly) {
    Write-StepHeader "Checking MailHog Availability"
    try {
        # Source the MailHog check script
        . $mailhogCheck
        
        # Run the MailHog check
        $mailhogStatus = Test-MailhogService
        
        if ($mailhogStatus.Success) {
            Write-StepResult -StepName "MailHog Service" -Success $true
            Write-Host "  - API Endpoint: Available" -ForegroundColor Green
            Write-Host "  - UI Available at: http://localhost:8025" -ForegroundColor Gray
            $mailhogAvailable = $true
        } else {
            Write-StepResult -StepName "MailHog Service" -Success $false -Details $mailhogStatus.Message
            $mailhogAvailable = $false
        }
    }
    catch {
        Write-StepResult -StepName "MailHog Service" -Success $false -Details $_.Exception.Message
        $mailhogAvailable = $false
    }
}

# Step 4: Run Unit Tests (unless API-only mode)
if (-not $ApiTestsOnly) {
    Write-StepHeader "Running Unit Tests"
    try {
        # Run Jest tests and capture output
        $testOutput = npm test 2>&1
        $testSuccess = $LASTEXITCODE -eq 0
        
        # Save test output to file
        $testOutputPath = Join-Path $testResultsDir "unit-test-results.txt"
        $testOutput | Out-File -FilePath $testOutputPath
        
        # Display result
        if ($testSuccess) {
            Write-StepResult -StepName "Unit Tests" -Success $true
            Write-Host "Test output saved to: $testOutputPath" -ForegroundColor Gray
        } else {
            Write-StepResult -StepName "Unit Tests" -Success $false -Details "Check test output for details"
            Write-Host "Test failures found. Output saved to: $testOutputPath" -ForegroundColor Yellow
            
            # Show the last 5 lines of test output if there were failures
            Write-Host "`nLast few lines of test output:" -ForegroundColor Yellow
            $testOutput | Select-Object -Last 5 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        }
    }
    catch {
        Write-StepResult -StepName "Unit Tests" -Success $false -Details $_.Exception.Message
    }
}

# Step 5: API Endpoint Testing (unless Unit-only mode)
if (-not $UnitTestsOnly -and $dockerAvailable) {
    Write-StepHeader "Testing API Endpoints"
    
    # Determine which API testing approach to use based on MailHog availability
    if ($mailhogAvailable) {
        Write-Host "MailHog is available - running email verification tests" -ForegroundColor Green
        try {
            # Run email-based tests with MailHog
            $mailhogTestsOutput = & ".\mailhog-email-tests.ps1" 2>&1
            $mailhogTestsSuccess = $LASTEXITCODE -eq 0
            
            # Save output
            $mailhogTestsOutputPath = Join-Path $testResultsDir "mailhog-tests-results.txt"
            $mailhogTestsOutput | Out-File -FilePath $mailhogTestsOutputPath
            
            Write-StepResult -StepName "MailHog Email Tests" -Success $mailhogTestsSuccess
        }
        catch {
            Write-StepResult -StepName "MailHog Email Tests" -Success $false -Details $_.Exception.Message
        }
    } else {
        Write-Host "MailHog is not available - running tests with email verification bypass" -ForegroundColor Yellow
        
        try {
            # Run auto verification tests (bypassing email verification)
            $autoVerifyOutput = & ".\auto-verify-tests.ps1" 2>&1
            $autoVerifySuccess = $LASTEXITCODE -eq 0
            
            # Save output
            $autoVerifyOutputPath = Join-Path $testResultsDir "auto-verify-results.txt"
            $autoVerifyOutput | Out-File -FilePath $autoVerifyOutputPath
            
            Write-StepResult -StepName "Auto Verification Tests" -Success $autoVerifySuccess
        }
        catch {
            Write-StepResult -StepName "Auto Verification Tests" -Success $false -Details $_.Exception.Message
        }
    }
    
    # Run the API tests to ensure all endpoints are tested
    try {
        $apiTestsOutput = & ".\auth-api-tests.ps1" 2>&1
        $apiTestsSuccess = $LASTEXITCODE -eq 0
        
        # Save output
        $apiTestsOutputPath = Join-Path $testResultsDir "api-tests-results.txt"
        $apiTestsOutput | Out-File -FilePath $apiTestsOutputPath
        
        Write-StepResult -StepName "API Endpoint Tests" -Success $apiTestsSuccess
    }
    catch {
        Write-StepResult -StepName "API Endpoint Tests" -Success $false -Details $_.Exception.Message
    }
}

# Step 6: Generate Summary Report
$pipelineTimer.Stop()
$elapsedTime = $pipelineTimer.Elapsed

Write-StepHeader "Testing Pipeline Summary"
Write-Host "Pipeline completed in: $($elapsedTime.ToString('hh\:mm\:ss'))" -ForegroundColor Gray
Write-Host "Test results directory: $testResultsDir" -ForegroundColor Gray

Write-Host "`nEnvironment Status:" -ForegroundColor Cyan
Write-Host "  - Docker Available: " -NoNewline
Write-Host $(if ($dockerAvailable) {"Yes"} else {"No"}) -ForegroundColor $(if ($dockerAvailable) {"Green"} else {"Red"})
Write-Host "  - MailHog Available: " -NoNewline
Write-Host $(if ($mailhogAvailable) {"Yes"} else {"No"}) -ForegroundColor $(if ($mailhogAvailable) {"Green"} else {"Yellow"})

# Save summary to file
$summaryPath = Join-Path $testResultsDir "pipeline-summary.txt"
@"
Authentication System Test Pipeline Summary
==========================================
Date: $(Get-Date)
Duration: $($elapsedTime.ToString('hh\:mm\:ss'))

Environment:
- Docker Available: $dockerAvailable
- MailHog Available: $mailhogAvailable
- Node.js Version: $nodeVersion
- NPM Version: $npmVersion

Test Results:
- Unit Tests: $(if ($ApiTestsOnly) {"Skipped"} elseif ($testSuccess) {"Passed"} else {"Failed"})
- API Tests: $(if ($UnitTestsOnly) {"Skipped"} elseif ($apiTestsSuccess) {"Passed"} else {"Failed"})
- Email Tests: $(if ($UnitTestsOnly -or -not $mailhogAvailable) {"Skipped"} elseif ($mailhogTestsSuccess) {"Passed"} else {"Failed"})
"@ | Out-File -FilePath $summaryPath

Write-Host "`nSummary saved to: $summaryPath" -ForegroundColor Gray
Write-Host "`nTesting Pipeline Completed!" -ForegroundColor Cyan

# Set exit code based on test results
if (
    ($ApiTestsOnly -and $apiTestsSuccess) -or
    ($UnitTestsOnly -and $testSuccess) -or
    (-not $ApiTestsOnly -and -not $UnitTestsOnly -and $testSuccess -and $apiTestsSuccess)
) {
    exit 0
} else {
    exit 1
}
#endregion