@echo off
:: User Listing Batch Script
:: This script runs the list_users.py script to display all users and their roles

echo ===== User Listing Utility =====
echo This script will list all users in the database with their roles.

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
pip install requests tabulate

:: Run the Python script
echo.
echo Running User Listing Script...
echo.
python list_users.py

echo.
if %ERRORLEVEL% EQU 0 (
    echo User listing completed successfully!
) else (
    echo Error occurred during user listing.
)

:: Deactivate the virtual environment
call venv\Scripts\deactivate.bat

pause