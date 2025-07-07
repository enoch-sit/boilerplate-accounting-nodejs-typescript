# User Creation PowerShell Script
# This script runs the create_users.py script to create admin, supervisor, and regular users

Write-Host "===== User Creation Utility =====" -ForegroundColor Cyan
Write-Host "This script will create default users with different roles in the database." -ForegroundColor White

# Check if Python is installed
try {
    $pythonVersion = python --version 2>&1
    Write-Host "Found Python: $pythonVersion" -ForegroundColor Green
}
catch {
    Write-Host "Error: Python is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Python 3.7+ and try again" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Check if virtual environment exists, if not create it
if (-not (Test-Path "venv")) {
    Write-Host "Creating virtual environment..." -ForegroundColor Yellow
    python -m venv venv
}

# Activate the virtual environment
Write-Host "Activating virtual environment..." -ForegroundColor Yellow
& .\venv\Scripts\Activate.ps1

# Install required packages in the virtual environment
Write-Host "Installing required packages..." -ForegroundColor Yellow
pip install requests

# Run the Python script
Write-Host "`nRunning User Creation Script...`n" -ForegroundColor Cyan
python create_users.py

# Check if the script was successful
if ($LASTEXITCODE -eq 0) {
    Write-Host "`nUser creation completed successfully!" -ForegroundColor Green
}
else {
    Write-Host "`nError occurred during user creation." -ForegroundColor Red
}

# Deactivate the virtual environment
deactivate

Read-Host "Press Enter to continue..."