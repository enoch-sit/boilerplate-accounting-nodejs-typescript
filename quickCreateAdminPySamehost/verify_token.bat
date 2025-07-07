@echo off
:: Verify Token Batch Script
:: This script runs verify_token.py to verify a JWT token

echo ===== JWT Token Verification Utility =====
echo This script will verify a JWT token using a secret key.

:: Check if Python is installed
python --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Error: Python is not installed or not in PATH
    echo Please install Python 3.7+ and try again
    pause
    exit /b 1
)

:: Run the Python script directly (no additional dependencies needed)
echo.
echo Running Token Verification Script...
echo.
python verify_token.py

echo.
if %ERRORLEVEL% EQU 0 (
    echo Token verification completed!
) else (
    echo Error occurred during token verification.
)

pause
