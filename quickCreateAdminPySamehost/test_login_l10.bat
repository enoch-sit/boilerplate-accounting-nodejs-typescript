@echo off
:: Test Login Batch Script
:: This script runs the test_login.py script to test login for all users and display JWT tokens

echo ===== JWT Login Test Utility =====
echo This script will test login for all users and display their JWT tokens.

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
echo Running Login Test Script...
echo.
python test_login_l10.py

echo.
if %ERRORLEVEL% EQU 0 (
    echo Login testing completed successfully!
) else (
    echo Error occurred during login testing.
)

:: Deactivate the virtual environment
call venv\Scripts\deactivate.bat

pause