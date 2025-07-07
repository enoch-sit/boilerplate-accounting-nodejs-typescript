@echo off
REM Remove All Users Script for Simple Accounting Authentication System
REM This script will remove ALL users from the database, including admins

echo.
echo ===========================================
echo    REMOVE ALL USERS - ADMIN SCRIPT
echo ===========================================
echo.
echo This script will permanently delete ALL users, including admins!
echo.

REM Check if Python is installed
where python >nul 2>nul
if %errorlevel% neq 0 (
    echo Python is not installed or not in PATH.
    echo Please install Python 3.6 or higher.
    echo.
    pause
    exit /b 1
)

REM Check if required Python packages are installed
python -c "import requests" >nul 2>nul
if %errorlevel% neq 0 (
    echo Installing required Python packages...
    pip install requests
)

REM Run the removal script
python remove_all_users.py

echo.
if %errorlevel% neq 0 (
    echo Script execution failed with error code %errorlevel%
) else (
    echo Script completed successfully!
)

echo.
pause