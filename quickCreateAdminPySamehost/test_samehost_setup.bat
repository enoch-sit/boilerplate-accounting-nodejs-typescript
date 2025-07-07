@echo off
:: test_samehost_setup.bat - Test script for samehost configuration

echo ===== Samehost Configuration Test =====
echo This script tests if your samehost Docker setup is working correctly.
echo.

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
    if %ERRORLEVEL% NEQ 0 (
        echo Error: Failed to create virtual environment
        pause
        exit /b 1
    )
)

:: Activate virtual environment
echo Activating virtual environment...
call venv\Scripts\activate.bat

:: Install required packages
echo Installing/updating required packages...
pip install requests >nul 2>&1

:: Run the test script
echo.
echo Running samehost configuration test...
python test_samehost_setup.py

:: Keep window open
echo.
echo Test completed. Press any key to exit...
pause >nul
