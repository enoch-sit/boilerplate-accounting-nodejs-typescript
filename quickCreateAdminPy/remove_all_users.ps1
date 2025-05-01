# Remove All Users PowerShell Script
# This script will remove ALL users from the database, including admins

Write-Host "===========================================" -ForegroundColor Red
Write-Host "    REMOVE ALL USERS - ADMIN SCRIPT" -ForegroundColor Red
Write-Host "===========================================" -ForegroundColor Red
Write-Host ""
Write-Host "This script will permanently delete ALL users, including admins!" -ForegroundColor Yellow
Write-Host ""

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
Write-Host "`nRunning User Removal Script...`n" -ForegroundColor Cyan
python remove_all_users.py

# Check if the script was successful
if ($LASTEXITCODE -eq 0) {
    Write-Host "`nUser removal completed successfully!" -ForegroundColor Green
}
else {
    Write-Host "`nScript execution failed with error code $LASTEXITCODE" -ForegroundColor Red
}

# Deactivate the virtual environment
deactivate

Read-Host "Press Enter to continue..."