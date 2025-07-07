@echo off
:: Get Token Batch Script
:: This script runs get_token.py to retrieve a JWT token for a user

echo ===== JWT Token Retrieval Utility =====
echo This script will log in as a user and retrieve their JWT token.

:: Check if Python is installed
python --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Error: Python is not installed or not in PATH
    echo Please install Python 3.7+ and try again
    pause
    exit /b 1
)

:: Check if virtual environment exists, if not create it
if not exist venv (
    echo Creating virtual environment...
    python -m venv venv
)

:: Activate the virtual environment
echo Activating virtual environment...
call venv\Scripts\activate.bat

:: Install required packages in the virtual environment
echo Installing required packages...
pip install requests

:: Run the Python script
echo.
echo Running Token Retrieval Script...
echo.
python get_token.py

echo.
if %ERRORLEVEL% EQU 0 (
    echo Token retrieval completed successfully!
) else (
    echo Error occurred during token retrieval.
)

:: Deactivate the virtual environment
call venv\Scripts\deactivate.bat

pause
