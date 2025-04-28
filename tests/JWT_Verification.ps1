# JWT_Verification.ps1
# PowerShell script to run the JWT verification tool
# Created: April 28, 2025

<#
.SYNOPSIS
    Runs the JWT verification tool for checking authentication tokens in development and production environments.

.DESCRIPTION
    This script activates a Python virtual environment (if it exists) and runs the JWT_verification.py tool.
    It passes through all command-line arguments to the Python script.

.PARAMETER Args
    Arguments to pass to the JWT_verification.py script.

.EXAMPLE
    .\JWT_Verification.ps1 verify --token eyJhbGciOi... --env dev
    Verifies a JWT token in the development environment.

.EXAMPLE
    .\JWT_Verification.ps1 check-env --env dev
    Checks JWT secrets in the development environment.

.EXAMPLE
    .\JWT_Verification.ps1 extract --docker-container auth-service-dev
    Extracts JWT-related environment variables from a Docker container.

.NOTES
    Author: Auth System Administrator
    Date:   April 28, 2025
#>

# Script configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PythonScript = Join-Path $ScriptDir "JWT_verification.py"
$VenvDir = Join-Path $ScriptDir ".venv"
$ProjectRoot = Split-Path -Parent $ScriptDir
$WindowsVenvActivate = Join-Path $VenvDir "Scripts\Activate.ps1"
$UnixVenvActivate = Join-Path $VenvDir "bin\Activate.ps1"
$PythonCmd = "python"

# Check if running in a Docker container
$InDocker = $env:RUNNING_IN_DOCKER -eq "true"

# Function to check if a command exists
function Test-CommandExists {
    param ($command)
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'stop'
    try {
        if (Get-Command $command -ErrorAction SilentlyContinue) { return $true }
    }
    catch {
        return $false
    }
    finally {
        $ErrorActionPreference = $oldPreference
    }
}

# Check which Python commands are available on the system
function Find-PythonCommand {
    $commands = @("python", "python3", "py")
    
    foreach ($cmd in $commands) {
        if (Test-CommandExists $cmd) {
            # Verify it's actually Python by checking version
            try {
                $version = & $cmd --version 2>&1
                if ($version -match "Python") {
                    return $cmd
                }
            } catch {
                # Command exists but can't execute version check
                continue
            }
        }
    }
    
    return $null
}

# Check if the script is installed and accessible
if (-not (Test-Path $PythonScript)) {
    Write-Error "Error: JWT_verification.py not found at $PythonScript"
    exit 1
}

# Find a working Python command
$PythonCmd = Find-PythonCommand
if (-not $PythonCmd) {
    Write-Host "Python was not found on your system. Please install Python 3.6 or newer." -ForegroundColor Red
    Write-Host "You can download Python from: https://www.python.org/downloads/" -ForegroundColor Yellow
    Write-Host "If Python is already installed, make sure it's in your PATH." -ForegroundColor Yellow
    
    # Check if Python is installed in common locations
    $CommonPythonPaths = @(
        "${env:ProgramFiles}\Python*\python.exe",
        "${env:ProgramFiles(x86)}\Python*\python.exe",
        "${env:LocalAppData}\Programs\Python\Python*\python.exe",
        "${env:USERPROFILE}\AppData\Local\Microsoft\WindowsApps\python.exe",
        "${env:USERPROFILE}\AppData\Local\Microsoft\WindowsApps\python3.exe"
    )
    
    $PythonFound = $false
    foreach ($path in $CommonPythonPaths) {
        $resolvedPaths = Resolve-Path $path -ErrorAction SilentlyContinue
        if ($resolvedPaths) {
            Write-Host "Python was found at: $($resolvedPaths.Path)" -ForegroundColor Cyan
            Write-Host "But it's not in your PATH environment variable." -ForegroundColor Cyan
            $PythonFound = $true
        }
    }
    
    if (-not $PythonFound) {
        Write-Host "No Python installation was found in common locations." -ForegroundColor Red
    }
    
    # Provide Docker alternative
    Write-Host "`nAlternatively, you can check JWT secrets using Docker directly:" -ForegroundColor Cyan
    Write-Host "docker exec auth-service-dev printenv | findstr JWT" -ForegroundColor Gray
    
    exit 1
}

# Make the script executable for non-Windows systems when used in WSL or similar
if (-not $InDocker -and (Test-CommandExists "chmod")) {
    & chmod +x $PythonScript
}

# Activate virtual environment if it exists
if (Test-Path $WindowsVenvActivate) {
    Write-Host "Activating virtual environment from $WindowsVenvActivate" -ForegroundColor Cyan
    & $WindowsVenvActivate
} elseif (Test-Path $UnixVenvActivate) {
    Write-Host "Activating virtual environment from $UnixVenvActivate" -ForegroundColor Cyan
    & $UnixVenvActivate
} else {
    Write-Host "No virtual environment found, using system Python: $PythonCmd" -ForegroundColor Cyan
}

# Check if required Python packages are installed (especially requests)
try {
    $CheckPackages = & $PythonCmd -c "import requests; print('Packages OK')" 2>&1
    if ($CheckPackages -ne "Packages OK") {
        Write-Host "Installing required packages..." -ForegroundColor Yellow
        & $PythonCmd -m pip install requests 2>&1 | Out-Null
    }
} catch {
    Write-Host "Installing required packages..." -ForegroundColor Yellow
    & $PythonCmd -m pip install requests 2>&1 | Out-Null
}

# Run the Python script with all arguments passed to this script
try {
    Write-Host "Running JWT verification tool..." -ForegroundColor Cyan
    & $PythonCmd $PythonScript $args
    
    # Check if the script executed successfully
    if ($LASTEXITCODE -ne 0) {
        Write-Host "JWT verification tool returned error code: $LASTEXITCODE" -ForegroundColor Red
        
        # If no args were provided but there was an error, we'll show manual JWT extraction command
        if ($args.Count -eq 0) {
            Write-Host "`nYou can check JWT secrets manually using Docker:" -ForegroundColor Yellow
            Write-Host "docker exec auth-service-dev printenv | findstr JWT" -ForegroundColor Gray
        }
    }
} catch {
    Write-Error "Error executing JWT verification tool: $_"
    Write-Host "`nYou can check JWT secrets manually using Docker:" -ForegroundColor Yellow
    Write-Host "docker exec auth-service-dev printenv | findstr JWT" -ForegroundColor Gray
    exit 1
}

# Show a helpful message with common commands
if ($args.Count -eq 0) {
    Write-Host "`nCommon commands:" -ForegroundColor Yellow
    Write-Host "  Verify a token:  .\JWT_Verification.ps1 verify --token <your-token> --env dev" -ForegroundColor Gray
    Write-Host "  Check env vars:  .\JWT_Verification.ps1 check-env --env dev" -ForegroundColor Gray
    Write-Host "  Check Docker:    .\JWT_Verification.ps1 extract --docker-container auth-service-dev" -ForegroundColor Gray
    Write-Host "  Check health:    .\JWT_Verification.ps1 health --env dev" -ForegroundColor Gray
    Write-Host "  Show help:       .\JWT_Verification.ps1 --help" -ForegroundColor Gray
    
    # Alternative method using Docker directly
    Write-Host "`nAlternative method using Docker directly:" -ForegroundColor Yellow
    Write-Host "  docker exec auth-service-dev printenv | findstr JWT" -ForegroundColor Gray
}