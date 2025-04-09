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

.PARAMETER Debug
    Run with maximum debugging information

.EXAMPLE
    .\test-pipeline.ps1

.EXAMPLE
    .\test-pipeline.ps1 -UnitTestsOnly

.EXAMPLE
    .\test-pipeline.ps1 -ApiTestsOnly -SkipDockerChecks

.EXAMPLE
    .\test-pipeline.ps1 -Debug

.NOTES
    Author: AuthSystem Team
    Date:   April 2025
#>

param (
    [switch]$UnitTestsOnly,
    [switch]$ApiTestsOnly,
    [switch]$SkipDockerChecks,
    [switch]$CiMode,
    [switch]$Verbose,
    [switch]$Debug
)

# Start with a clean slate for debug information
$DebugPreference = "SilentlyContinue"
$VerbosePreference = "SilentlyContinue"
$ErrorActionPreference = "Stop"

# Set up a log file for all debug output
$logDate = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logDir = Join-Path $scriptDir "logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}
$logFile = Join-Path $logDir "test-pipeline_$logDate.log"
# Create a separate custom log file to avoid file locking conflicts
$customLogFile = Join-Path $logDir "test-pipeline_custom_$logDate.log"

# Configure preferences based on parameters
if ($Debug) {
    $DebugPreference = "Continue"
    $VerbosePreference = "Continue"
    $ErrorActionPreference = "Continue"
    Write-Host "Debug mode enabled. All output will be logged to: $logFile" -ForegroundColor Magenta
} elseif ($Verbose) {
    $VerbosePreference = "Continue"
    $ErrorActionPreference = "Continue"
    Write-Host "Verbose mode enabled. All output will be logged to: $logFile" -ForegroundColor Magenta
}

# Start transcript to capture all console output
Start-Transcript -Path $logFile -Append

function Write-DebugInfo {
    param (
        [string]$Message,
        [string]$Category = "INFO",
        [ConsoleColor]$Color = [ConsoleColor]::Gray
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Category] $Message"
    
    if ($Debug -or $Verbose) {
        Write-Host $logMessage -ForegroundColor $Color
    }
    
    # Always write to custom log file regardless of debug/verbose mode
    $logMessage | Out-File -FilePath $customLogFile -Append
}

# Script locations
$dockerHealthCheck = Join-Path $scriptDir "docker-health-check.ps1"
$mailhogCheck = Join-Path $scriptDir "mailhog-check.ps1"

# Application URLs
$appBaseUrl = "http://localhost:3000"
$mailhogApiUrl = "http://localhost:8025"

# Set up test results directory
$testResultsDir = Join-Path $scriptDir "test-results"
if (-not (Test-Path $testResultsDir)) {
    New-Item -ItemType Directory -Path $testResultsDir | Out-Null
    Write-DebugInfo "Created test results directory: $testResultsDir" "SETUP" Yellow
}

# Start timer for overall pipeline execution
$pipelineTimer = [System.Diagnostics.Stopwatch]::StartNew()
Write-DebugInfo "Pipeline timer started" "TIMER" Cyan

#region Helper Functions
function Write-StepHeader {
    param (
        [string]$Message
    )
    
    $headerText = "`n===============================================`n  $Message`n==============================================="
    Write-Host $headerText -ForegroundColor Cyan
    Write-DebugInfo "STARTING STEP: $Message" "STEP" Cyan
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
        Write-DebugInfo "$StepName - PASSED" "SUCCESS" Green
    } else {
        Write-Host "❌ $StepName - " -ForegroundColor Red -NoNewline
        Write-Host "FAILED" -ForegroundColor Red
        Write-DebugInfo "$StepName - FAILED: $Details" "ERROR" Red
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
    
    Write-DebugInfo "Testing API endpoint: $Method $Endpoint" "API" Cyan
    
    try {
        $params = @{
            Uri = "$appBaseUrl$Endpoint"
            Method = $Method
            ContentType = "application/json"
            ErrorAction = "Stop"
        }
        
        if ($Body) {
            $bodyJson = $Body | ConvertTo-Json -Compress
            $params.Body = $bodyJson
            Write-DebugInfo "Request body: $bodyJson" "API" Cyan
        }
        
        if ($Headers.Count -gt 0) {
            $params.Headers = $Headers
            Write-DebugInfo "Request headers: $($Headers | ConvertTo-Json -Compress)" "API" Cyan
        }
        
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $response = Invoke-RestMethod @params
        $sw.Stop()
        
        Write-DebugInfo "API call successful in $($sw.ElapsedMilliseconds)ms" "API" Green
        Write-DebugInfo "Response: $($response | ConvertTo-Json -Depth 3 -Compress)" "API" Green
        
        return @{
            Success = $true
            Response = $response
            Duration = $sw.ElapsedMilliseconds
        }
    }
    catch {
        Write-DebugInfo "API call failed: $($_.Exception.Message)" "API" Red
        Write-DebugInfo "Stack trace: $($_.ScriptStackTrace)" "API" Red
        
        if ($_.Exception.Response) {
            try {
                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $reader.BaseStream.Position = 0
                $reader.DiscardBufferedData()
                $responseBody = $reader.ReadToEnd()
                Write-DebugInfo "Error response body: $responseBody" "API" Red
            } catch {
                Write-DebugInfo "Could not read error response body: $($_.Exception.Message)" "API" Red
            }
        }
        
        return @{
            Success = $false
            Error = $_.Exception.Message
            Response = $null
            StatusCode = $_.Exception.Response.StatusCode.value__
        }
    }
}

function Get-SystemInfo {
    Write-DebugInfo "Collecting system information..." "SYSINFO" Yellow
    
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $osInfo = "$($os.Caption) $($os.Version) Build $($os.BuildNumber)"
        Write-DebugInfo "OS: $osInfo" "SYSINFO" Yellow
        
        $memory = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
        Write-DebugInfo "Memory: $memory GB" "SYSINFO" Yellow
        
        $processor = Get-CimInstance Win32_Processor | Select-Object -First 1
        Write-DebugInfo "Processor: $($processor.Name)" "SYSINFO" Yellow
        
        $diskSpace = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" | 
                     Select-Object @{Name="FreeSpace";Expression={[math]::Round($_.FreeSpace / 1GB, 2)}}
        Write-DebugInfo "Free Disk Space: $($diskSpace.FreeSpace) GB" "SYSINFO" Yellow
        
        return @{
            OS = $osInfo
            Memory = "$memory GB"
            Processor = $processor.Name
            FreeSpace = "$($diskSpace.FreeSpace) GB"
        }
    } catch {
        Write-DebugInfo "Error collecting system information: $($_.Exception.Message)" "SYSINFO" Red
        return @{
            Error = $_.Exception.Message
        }
    }
}
#endregion

#region Main Pipeline Execution
Write-StepHeader "Starting Authentication System Testing Pipeline"
Write-Host "Time: $(Get-Date)" -ForegroundColor Gray
Write-Host "Mode: $(if($UnitTestsOnly){'Unit Tests Only'} elseif($ApiTestsOnly){'API Tests Only'} else {'Full Pipeline'})" -ForegroundColor Gray
Write-DebugInfo "Parameters:" "CONFIG" Yellow
Write-DebugInfo "  UnitTestsOnly: $UnitTestsOnly" "CONFIG" Yellow
Write-DebugInfo "  ApiTestsOnly: $ApiTestsOnly" "CONFIG" Yellow
Write-DebugInfo "  SkipDockerChecks: $SkipDockerChecks" "CONFIG" Yellow
Write-DebugInfo "  CiMode: $CiMode" "CONFIG" Yellow
Write-DebugInfo "  Verbose: $Verbose" "CONFIG" Yellow
Write-DebugInfo "  Debug: $Debug" "CONFIG" Yellow

# Collect system information at the start
$sysInfo = Get-SystemInfo
Write-DebugInfo "System information collected" "SYSINFO" Yellow

# Step 1: Check if we're running the right Node.js version
Write-StepHeader "Checking Node.js Environment"
try {
    Write-DebugInfo "Checking Node.js version" "NODE" Cyan
    $nodeVersion = node -v
    $npmVersion = npm -v
    Write-Host "Node.js Version: $nodeVersion" -ForegroundColor Green
    Write-Host "NPM Version: $npmVersion" -ForegroundColor Green
    Write-DebugInfo "Node.js: $nodeVersion, NPM: $npmVersion" "NODE" Green
    
    # Check if node version is 18+
    if ($nodeVersion -match 'v(\d+)' -and [int]$matches[1] -ge 18) {
        Write-StepResult -StepName "Node.js Version Check" -Success $true
    } else {
        Write-DebugInfo "Node.js version below requirement. Found: $nodeVersion, Required: v18+" "NODE" Red
        Write-StepResult -StepName "Node.js Version Check" -Success $false -Details "Node.js v18+ is required"
    }
}
catch {
    Write-DebugInfo "Error checking Node.js: $($_.Exception.Message)" "NODE" Red
    Write-DebugInfo "Stack trace: $($_.ScriptStackTrace)" "NODE" Red
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
        Write-DebugInfo "Loading Docker health check script: $dockerHealthCheck" "DOCKER" Cyan
        # Source the Docker health check script
        . $dockerHealthCheck
        
        Write-DebugInfo "Running Docker environment check" "DOCKER" Cyan
        # Run the Docker health check
        $dockerStatus = Test-DockerEnvironment
        
        if ($dockerStatus.Success) {
            Write-StepResult -StepName "Docker Environment" -Success $true
            Write-DebugInfo "Docker environment check passed" "DOCKER" Green
            foreach ($container in $dockerStatus.Containers) {
                Write-Host "  - $($container.Name): " -NoNewline
                if ($container.Running) {
                    Write-Host "Running" -ForegroundColor Green
                    Write-DebugInfo "Container $($container.Name): Running" "DOCKER" Green
                } else {
                    Write-Host "Stopped" -ForegroundColor Red
                    Write-DebugInfo "Container $($container.Name): Stopped" "DOCKER" Red
                    $dockerAvailable = $false
                }
                
                if ($Debug) {
                    Write-DebugInfo "Container details: $($container | ConvertTo-Json)" "DOCKER" Cyan
                }
            }
        } else {
            Write-StepResult -StepName "Docker Environment" -Success $false -Details $dockerStatus.Message
            Write-DebugInfo "Docker environment check failed: $($dockerStatus.Message)" "DOCKER" Red
            $dockerAvailable = $false
        }
    }
    catch {
        Write-DebugInfo "Error in Docker check: $($_.Exception.Message)" "DOCKER" Red
        Write-DebugInfo "Stack trace: $($_.ScriptStackTrace)" "DOCKER" Red
        Write-StepResult -StepName "Docker Environment" -Success $false -Details $_.Exception.Message
        $dockerAvailable = $false
    }
}
else {
    Write-DebugInfo "Docker checks skipped due to -SkipDockerChecks parameter" "DOCKER" Yellow
}

# Step 3: MailHog Check (if Docker is available and not skipped)
$mailhogAvailable = $false
if ($dockerAvailable -and -not $SkipDockerChecks -and -not $UnitTestsOnly) {
    Write-StepHeader "Checking MailHog Availability"
    try {
        Write-DebugInfo "Loading MailHog check script: $mailhogCheck" "MAILHOG" Cyan
        # Source the MailHog check script
        . $mailhogCheck
        
        Write-DebugInfo "Running MailHog service check" "MAILHOG" Cyan
        # Run the MailHog check
        $mailhogStatus = Test-MailHogFunctionality
        
        if ($mailhogStatus.Success) {
            Write-StepResult -StepName "MailHog Service" -Success $true
            Write-DebugInfo "MailHog service check passed" "MAILHOG" Green
            Write-Host "  - API Endpoint: Available" -ForegroundColor Green
            Write-Host "  - UI Available at: http://localhost:8025" -ForegroundColor Gray
            $mailhogAvailable = $true
            
            if ($Debug) {
                Write-DebugInfo "MailHog status details: $($mailhogStatus | ConvertTo-Json)" "MAILHOG" Cyan
            }
        } else {
            Write-StepResult -StepName "MailHog Service" -Success $false -Details $mailhogStatus.Message
            Write-DebugInfo "MailHog service check failed: $($mailhogStatus.Message)" "MAILHOG" Red
            $mailhogAvailable = $false
            
            # Check if the container is found but stopped
            $mailhogContainerStopped = $false
            if ($dockerStatus -and $dockerStatus.Containers) {
                $mailhogContainer = $dockerStatus.Containers | Where-Object { $_.Name -match "mailhog|auth-service-mailhog" }
                if ($mailhogContainer -and -not $mailhogContainer.Running) {
                    $mailhogContainerStopped = $true
                    Write-Host "  - MailHog container found but not running. Try starting it with:" -ForegroundColor Yellow
                    Write-Host "    docker start $($mailhogContainer.Name)" -ForegroundColor Yellow
                    Write-DebugInfo "MailHog container found but stopped: $($mailhogContainer.Name)" "MAILHOG" Yellow
                }
            }
        }
    }
    catch {
        Write-DebugInfo "Error in MailHog check: $($_.Exception.Message)" "MAILHOG" Red
        Write-DebugInfo "Stack trace: $($_.ScriptStackTrace)" "MAILHOG" Red
        Write-StepResult -StepName "MailHog Service" -Success $false -Details $_.Exception.Message
        $mailhogAvailable = $false
    }
}
else {
    if ($UnitTestsOnly) {
        Write-DebugInfo "MailHog check skipped due to -UnitTestsOnly parameter" "MAILHOG" Yellow
    } elseif (-not $dockerAvailable) {
        Write-DebugInfo "MailHog check skipped because Docker is not available" "MAILHOG" Yellow
    } else {
        Write-DebugInfo "MailHog check skipped due to -SkipDockerChecks parameter" "MAILHOG" Yellow
    }
}

# Step 4: Run Unit Tests (unless API-only mode)
$testSuccess = $false
if (-not $ApiTestsOnly) {
    Write-StepHeader "Running Unit Tests"
    try {
        Write-DebugInfo "Executing Jest unit tests" "UNIT" Cyan
        # Run Jest tests and capture output
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $testOutput = npm test 2>&1
        $testExitCode = $LASTEXITCODE
        $sw.Stop()
        Write-DebugInfo "Unit tests completed in $($sw.ElapsedMilliseconds)ms with exit code: $testExitCode" "UNIT" $(if ($testExitCode -eq 0) { "Green" } else { "Red" })
        $testSuccess = $testExitCode -eq 0
        
        # Save test output to file
        $testOutputPath = Join-Path $testResultsDir "unit-test-results.txt"
        $testOutput | Out-File -FilePath $testOutputPath
        Write-DebugInfo "Unit test output saved to: $testOutputPath" "UNIT" Cyan
        
        # Save a JSON summary with more details
        $testJsonPath = Join-Path $testResultsDir "unit-test-results.json"
        @{
            Success = $testSuccess
            ExitCode = $testExitCode
            Duration = $sw.ElapsedMilliseconds
            ExecutedAt = (Get-Date).ToString("o")
            OutputPath = $testOutputPath
        } | ConvertTo-Json | Out-File -FilePath $testJsonPath
        Write-DebugInfo "Unit test JSON summary saved to: $testJsonPath" "UNIT" Cyan
        
        # Display result
        if ($testSuccess) {
            Write-StepResult -StepName "Unit Tests" -Success $true
            Write-Host "Test output saved to: $testOutputPath" -ForegroundColor Gray
        } else {
            Write-StepResult -StepName "Unit Tests" -Success $false -Details "Check test output for details"
            Write-Host "Test failures found. Output saved to: $testOutputPath" -ForegroundColor Yellow
            
            # Show the last 10 lines of test output if there were failures (increased from 5)
            Write-Host "`nLast few lines of test output:" -ForegroundColor Yellow
            $testOutput | Select-Object -Last 10 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
            
            # Try to parse the output for specific error messages
            $errorLines = $testOutput | Where-Object { $_ -match "Error:|FAIL |fail:|AssertionError:" }
            if ($errorLines) {
                Write-Host "`nDetected Error Messages:" -ForegroundColor Red
                $errorLines | Select-Object -First 5 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
                Write-DebugInfo "Detected error messages in unit tests: $($errorLines -join "`n")" "UNIT" Red
            }
        }
    }
    catch {
        Write-DebugInfo "Error running unit tests: $($_.Exception.Message)" "UNIT" Red
        Write-DebugInfo "Stack trace: $($_.ScriptStackTrace)" "UNIT" Red
        Write-StepResult -StepName "Unit Tests" -Success $false -Details $_.Exception.Message
    }
}
else {
    Write-DebugInfo "Unit tests skipped due to -ApiTestsOnly parameter" "UNIT" Yellow
}

# Step 5: API Endpoint Testing (unless Unit-only mode)
$apiTestsSuccess = $false
$mailhogTestsSuccess = $false
$autoVerifySuccess = $false

if (-not $UnitTestsOnly -and $dockerAvailable) {
    Write-StepHeader "Testing API Endpoints"
    
    # Determine which API testing approach to use based on MailHog availability
    if ($mailhogAvailable) {
        Write-Host "MailHog is available - running email verification tests" -ForegroundColor Green
        Write-DebugInfo "Running email verification tests with MailHog" "API" Cyan
        try {
            # Run email-based tests with MailHog
            Write-DebugInfo "Starting mailhog-email-tests.ps1 script" "API" Cyan
            $runParams = @()
            if ($Verbose) { $runParams += "-Verbose" }
            if ($Debug) { $runParams += "-Debug" }
            
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $mailhogTestsOutput = & ".\mailhog-email-tests.ps1" $runParams 2>&1
            $mailhogTestsExitCode = $LASTEXITCODE
            $sw.Stop()
            
            $mailhogTestsSuccess = $mailhogTestsExitCode -eq 0
            Write-DebugInfo "MailHog email tests completed in $($sw.ElapsedMilliseconds)ms with exit code: $mailhogTestsExitCode" "API" $(if ($mailhogTestsSuccess) { "Green" } else { "Red" })
            
            # Save output
            $mailhogTestsOutputPath = Join-Path $testResultsDir "mailhog-tests-results.txt"
            $mailhogTestsOutput | Out-File -FilePath $mailhogTestsOutputPath
            Write-DebugInfo "MailHog test output saved to: $mailhogTestsOutputPath" "API" Cyan
            
            # Save JSON summary
            $mailhogJsonPath = Join-Path $testResultsDir "mailhog-tests-results.json"
            @{
                Success = $mailhogTestsSuccess
                ExitCode = $mailhogTestsExitCode
                Duration = $sw.ElapsedMilliseconds
                ExecutedAt = (Get-Date).ToString("o")
                OutputPath = $mailhogTestsOutputPath
            } | ConvertTo-Json | Out-File -FilePath $mailhogJsonPath
            
            Write-StepResult -StepName "MailHog Email Tests" -Success $mailhogTestsSuccess
            
            # Print key error messages if test failed
            if (-not $mailhogTestsSuccess) {
                $errorLines = $mailhogTestsOutput | Where-Object { $_ -match "❌|Error:|failed|Failed" }
                if ($errorLines) {
                    Write-Host "`nKey error messages from MailHog tests:" -ForegroundColor Red
                    $errorLines | Select-Object -First 5 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
                    Write-DebugInfo "MailHog test error messages: $($errorLines -join "`n")" "API" Red
                }
            }
        }
        catch {
            Write-DebugInfo "Error running MailHog tests: $($_.Exception.Message)" "API" Red
            Write-DebugInfo "Stack trace: $($_.ScriptStackTrace)" "API" Red
            Write-StepResult -StepName "MailHog Email Tests" -Success $false -Details $_.Exception.Message
        }
    } else {
        Write-Host "MailHog is not available - running tests with email verification bypass" -ForegroundColor Yellow
        Write-DebugInfo "Running automated verification tests without MailHog" "API" Yellow
        
        try {
            # Run auto verification tests (bypassing email verification)
            Write-DebugInfo "Starting auto-verify-tests.ps1 script" "API" Cyan
            $runParams = @()
            if ($Verbose) { $runParams += "-Verbose" }
            if ($Debug) { $runParams += "-Debug" }
            
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $autoVerifyOutput = & ".\auto-verify-tests.ps1" $runParams 2>&1
            $autoVerifyExitCode = $LASTEXITCODE
            $sw.Stop()
            
            $autoVerifySuccess = $autoVerifyExitCode -eq 0
            Write-DebugInfo "Auto verification tests completed in $($sw.ElapsedMilliseconds)ms with exit code: $autoVerifyExitCode" "API" $(if ($autoVerifySuccess) { "Green" } else { "Red" })
            
            # Save output
            $autoVerifyOutputPath = Join-Path $testResultsDir "auto-verify-results.txt"
            $autoVerifyOutput | Out-File -FilePath $autoVerifyOutputPath
            Write-DebugInfo "Auto-verify test output saved to: $autoVerifyOutputPath" "API" Cyan
            
            # Save JSON summary
            $autoVerifyJsonPath = Join-Path $testResultsDir "auto-verify-results.json"
            @{
                Success = $autoVerifySuccess
                ExitCode = $autoVerifyExitCode
                Duration = $sw.ElapsedMilliseconds
                ExecutedAt = (Get-Date).ToString("o")
                OutputPath = $autoVerifyOutputPath
            } | ConvertTo-Json | Out-File -FilePath $autoVerifyJsonPath
            
            Write-StepResult -StepName "Auto Verification Tests" -Success $autoVerifySuccess
            
            # Print key error messages if test failed
            if (-not $autoVerifySuccess) {
                $errorLines = $autoVerifyOutput | Where-Object { $_ -match "❌|Error:|failed|Failed" }
                if ($errorLines) {
                    Write-Host "`nKey error messages from Auto Verification tests:" -ForegroundColor Red
                    $errorLines | Select-Object -First 5 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
                    Write-DebugInfo "Auto-verify test error messages: $($errorLines -join "`n")" "API" Red
                }
            }
        }
        catch {
            Write-DebugInfo "Error running Auto Verification tests: $($_.Exception.Message)" "API" Red
            Write-DebugInfo "Stack trace: $($_.ScriptStackTrace)" "API" Red
            Write-StepResult -StepName "Auto Verification Tests" -Success $false -Details $_.Exception.Message
        }
    }
    
    # Run the API tests to ensure all endpoints are tested
    try {
        Write-DebugInfo "Starting auth-api-tests.ps1 script" "API" Cyan
        $runParams = @()
        if ($Verbose) { $runParams += "-Verbose" }
        if ($Debug) { $runParams += "-Debug" }
        
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $apiTestsOutput = & ".\auth-api-tests.ps1" $runParams 2>&1
        $apiTestsExitCode = $LASTEXITCODE
        $sw.Stop()
        
        $apiTestsSuccess = $apiTestsExitCode -eq 0
        Write-DebugInfo "API tests completed in $($sw.ElapsedMilliseconds)ms with exit code: $apiTestsExitCode" "API" $(if ($apiTestsSuccess) { "Green" } else { "Red" })
        
        # Save output
        $apiTestsOutputPath = Join-Path $testResultsDir "api-tests-results.txt"
        $apiTestsOutput | Out-File -FilePath $apiTestsOutputPath
        Write-DebugInfo "API test output saved to: $apiTestsOutputPath" "API" Cyan
        
        # Save JSON summary
        $apiJsonPath = Join-Path $testResultsDir "api-tests-results.json"
        @{
            Success = $apiTestsSuccess
            ExitCode = $apiTestsExitCode
            Duration = $sw.ElapsedMilliseconds
            ExecutedAt = (Get-Date).ToString("o")
            OutputPath = $apiTestsOutputPath
        } | ConvertTo-Json | Out-File -FilePath $apiJsonPath
        
        Write-StepResult -StepName "API Endpoint Tests" -Success $apiTestsSuccess
        
        # Print key error messages if test failed
        if (-not $apiTestsSuccess) {
            $errorLines = $apiTestsOutput | Where-Object { $_ -match "❌|Error:|failed|Failed" }
            if ($errorLines) {
                Write-Host "`nKey error messages from API tests:" -ForegroundColor Red
                $errorLines | Select-Object -First 5 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
                Write-DebugInfo "API test error messages: $($errorLines -join "`n")" "API" Red
            }
        }
    }
    catch {
        Write-DebugInfo "Error running API tests: $($_.Exception.Message)" "API" Red
        Write-DebugInfo "Stack trace: $($_.ScriptStackTrace)" "API" Red
        Write-StepResult -StepName "API Endpoint Tests" -Success $false -Details $_.Exception.Message
    }
}
else {
    if ($UnitTestsOnly) {
        Write-DebugInfo "API tests skipped due to -UnitTestsOnly parameter" "API" Yellow
    } else {
        Write-DebugInfo "API tests skipped because Docker is not available" "API" Yellow
    }
}

# Step 6: Generate Summary Report
$pipelineTimer.Stop()
$elapsedTime = $pipelineTimer.Elapsed
Write-DebugInfo "Pipeline completed in $($elapsedTime.ToString('hh\:mm\:ss'))" "TIMER" Cyan

Write-StepHeader "Testing Pipeline Summary"
Write-Host "Pipeline completed in: $($elapsedTime.ToString('hh\:mm\:ss'))" -ForegroundColor Gray
Write-Host "Test results directory: $testResultsDir" -ForegroundColor Gray
Write-Host "Log file: $logFile" -ForegroundColor Gray

Write-Host "`nEnvironment Status:" -ForegroundColor Cyan
Write-Host "  - Docker Available: " -NoNewline
Write-Host $(if ($dockerAvailable) {"Yes"} else {"No"}) -ForegroundColor $(if ($dockerAvailable) {"Green"} else {"Red"})
Write-Host "  - MailHog Available: " -NoNewline
Write-Host $(if ($mailhogAvailable) {"Yes"} else {"No"}) -ForegroundColor $(if ($mailhogAvailable) {"Green"} else {"Yellow"})
Write-Host "  - Node.js Version: $nodeVersion" -ForegroundColor Gray
Write-Host "  - NPM Version: $npmVersion" -ForegroundColor Gray
Write-Host "  - OS: $($sysInfo.OS)" -ForegroundColor Gray

Write-Host "`nTest Results:" -ForegroundColor Cyan
Write-Host "  - Unit Tests: " -NoNewline
if ($ApiTestsOnly) {
    Write-Host "Skipped" -ForegroundColor Yellow
} elseif ($testSuccess) {
    Write-Host "PASSED" -ForegroundColor Green
} else {
    Write-Host "FAILED" -ForegroundColor Red
}

Write-Host "  - API Tests: " -NoNewline
if ($UnitTestsOnly) {
    Write-Host "Skipped" -ForegroundColor Yellow
} elseif ($apiTestsSuccess) {
    Write-Host "PASSED" -ForegroundColor Green
} else {
    Write-Host "FAILED" -ForegroundColor Red
}

Write-Host "  - Email Tests: " -NoNewline
if ($UnitTestsOnly -or -not $mailhogAvailable) {
    Write-Host "Skipped" -ForegroundColor Yellow
} elseif ($mailhogTestsSuccess) {
    Write-Host "PASSED" -ForegroundColor Green
} else {
    Write-Host "FAILED" -ForegroundColor Red
}

Write-Host "  - Auto-Verification Tests: " -NoNewline
if ($UnitTestsOnly -or $mailhogAvailable) {
    Write-Host "Skipped" -ForegroundColor Yellow
} elseif ($autoVerifySuccess) {
    Write-Host "PASSED" -ForegroundColor Green
} else {
    Write-Host "FAILED" -ForegroundColor Red
}

# Save summary to file with more detailed information
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
- OS: $($sysInfo.OS)
- Memory: $($sysInfo.Memory)
- Processor: $($sysInfo.Processor)
- Free Disk Space: $($sysInfo.FreeSpace)

Test Results:
- Unit Tests: $(if ($ApiTestsOnly) {"Skipped"} elseif ($testSuccess) {"Passed"} else {"Failed"})
- API Tests: $(if ($UnitTestsOnly) {"Skipped"} elseif ($apiTestsSuccess) {"Passed"} else {"Failed"})
- Email Tests: $(if ($UnitTestsOnly -or -not $mailhogAvailable) {"Skipped"} elseif ($mailhogTestsSuccess) {"Passed"} else {"Failed"})
- Auto-Verification Tests: $(if ($UnitTestsOnly -or $mailhogAvailable) {"Skipped"} elseif ($autoVerifySuccess) {"Passed"} else {"Failed"})

Run Configuration:
- Unit Tests Only: $UnitTestsOnly
- API Tests Only: $ApiTestsOnly
- Skip Docker Checks: $SkipDockerChecks
- CI Mode: $CiMode
- Debug Mode: $Debug

Result Files:
- Log File: $logFile
- Unit Test Results: $(if (-not $ApiTestsOnly) {"$testOutputPath"} else {"Skipped"})
- API Test Results: $(if (-not $UnitTestsOnly) {"$apiTestsOutputPath"} else {"Skipped"})
- MailHog Test Results: $(if (-not $UnitTestsOnly -and $mailhogAvailable) {"$mailhogTestsOutputPath"} else {"Skipped"})
- Auto-Verification Results: $(if (-not $UnitTestsOnly -and -not $mailhogAvailable) {"$autoVerifyOutputPath"} else {"Skipped"})
"@ | Out-File -FilePath $summaryPath

# Save JSON summary for programmatic access
$jsonSummaryPath = Join-Path $testResultsDir "pipeline-summary.json"
@{
    Date = (Get-Date).ToString("o")
    Duration = $elapsedTime.TotalMilliseconds
    Environment = @{
        DockerAvailable = $dockerAvailable
        MailhogAvailable = $mailhogAvailable
        NodeVersion = $nodeVersion
        NpmVersion = $npmVersion
        OS = $sysInfo.OS
        Memory = $sysInfo.Memory
        Processor = $sysInfo.Processor
        FreeSpace = $sysInfo.FreeSpace
    }
    TestResults = @{
        UnitTests = @{
            Status = if ($ApiTestsOnly) {"Skipped"} elseif ($testSuccess) {"Passed"} else {"Failed"}
            OutputPath = if (-not $ApiTestsOnly) {$testOutputPath} else {$null}
        }
        ApiTests = @{
            Status = if ($UnitTestsOnly) {"Skipped"} elseif ($apiTestsSuccess) {"Passed"} else {"Failed"}
            OutputPath = if (-not $UnitTestsOnly) {$apiTestsOutputPath} else {$null}
        }
        EmailTests = @{
            Status = if ($UnitTestsOnly -or -not $mailhogAvailable) {"Skipped"} elseif ($mailhogTestsSuccess) {"Passed"} else {"Failed"}
            OutputPath = if (-not $UnitTestsOnly -and $mailhogAvailable) {$mailhogTestsOutputPath} else {$null}
        }
        AutoVerificationTests = @{
            Status = if ($UnitTestsOnly -or $mailhogAvailable) {"Skipped"} elseif ($autoVerifySuccess) {"Passed"} else {"Failed"}
            OutputPath = if (-not $UnitTestsOnly -and -not $mailhogAvailable) {$autoVerifyOutputPath} else {$null}
        }
    }
    Configuration = @{
        UnitTestsOnly = $UnitTestsOnly
        ApiTestsOnly = $ApiTestsOnly
        SkipDockerChecks = $SkipDockerChecks
        CiMode = $CiMode
        Debug = $Debug
    }
    LogFile = $logFile
} | ConvertTo-Json -Depth 4 | Out-File -FilePath $jsonSummaryPath

Write-Host "`nSummary saved to: $summaryPath" -ForegroundColor Gray
Write-Host "JSON summary saved to: $jsonSummaryPath" -ForegroundColor Gray
Write-Host "`nTesting Pipeline Completed!" -ForegroundColor Cyan

# Stop the transcript
Stop-Transcript

# Set exit code based on test results
if (
    ($ApiTestsOnly -and $apiTestsSuccess) -or
    ($UnitTestsOnly -and $testSuccess) -or
    (-not $ApiTestsOnly -and -not $UnitTestsOnly -and $testSuccess -and $apiTestsSuccess)
) {
    Write-DebugInfo "Pipeline succeeded, exiting with code 0" "EXIT" Green
    exit 0
} else {
    Write-DebugInfo "Pipeline failed, exiting with code 1" "EXIT" Red
    exit 1
}
#endregion