@echo off
:: User Creation Batch Script
:: This script runs the create_users.py script to create admin, supervisor, and regular users

echo ===== User Creation Utility =====
echo This script will create default users with different roles in the database.

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
echo Running User Creation Script...
echo.
python create_users.py

echo.
if %ERRORLEVEL% EQU 0 (
    echo User creation completed successfully!
) else (
    echo Error occurred during user creation.
)

:: Deactivate the virtual environment
call venv\Scripts\deactivate.bat

pause