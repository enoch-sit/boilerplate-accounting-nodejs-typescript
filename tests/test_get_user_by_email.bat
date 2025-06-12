@echo off
:: Test Get User by Email API Endpoint
:: This script runs the Python test for the GET /api/admin/users/by-email/:email endpoint

echo ===== GET USER BY EMAIL API ENDPOINT TEST =====
echo This script will test the new GET /api/admin/users/by-email/:email endpoint

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

:: Activate the virtual environment
echo Activating virtual environment...
call venv\Scripts\activate.bat
if %ERRORLEVEL% NEQ 0 (
    echo Error: Failed to activate virtual environment
    pause
    exit /b 1
)

:: Install required packages in the virtual environment
echo Installing required packages...
pip install requests urllib3

:: Parse command line arguments
set "PYTHON_ARGS="
set "EMAIL_TO_TEST="
set "ADMIN_USERNAME=admin"
set "ADMIN_PASSWORD=admin@admin"
set "API_URL=http://localhost:3000"
set "SKIP_HEALTH_CHECK="

:: Simple argument parsing
:parse_args
if "%~1"=="" goto :run_test
if "%~1"=="--email" (
    set "EMAIL_TO_TEST=%~2"
    set "PYTHON_ARGS=%PYTHON_ARGS% --email %~2"
    shift
    shift
    goto :parse_args
)
if "%~1"=="--admin-username" (
    set "ADMIN_USERNAME=%~2"
    set "PYTHON_ARGS=%PYTHON_ARGS% --admin-username %~2"
    shift
    shift
    goto :parse_args
)
if "%~1"=="--admin-password" (
    set "ADMIN_PASSWORD=%~2"
    set "PYTHON_ARGS=%PYTHON_ARGS% --admin-password %~2"
    shift
    shift
    goto :parse_args
)
if "%~1"=="--api-url" (
    set "API_URL=%~2"
    set "PYTHON_ARGS=%PYTHON_ARGS% --api-url %~2"
    shift
    shift
    goto :parse_args
)
if "%~1"=="--skip-health-check" (
    set "SKIP_HEALTH_CHECK=1"
    set "PYTHON_ARGS=%PYTHON_ARGS% --skip-health-check"
    shift
    goto :parse_args
)
if "%~1"=="--help" goto :show_help
:: Unknown argument, just pass it through
set "PYTHON_ARGS=%PYTHON_ARGS% %~1"
shift
goto :parse_args

:run_test
echo.
echo Configuration:
echo - API URL: %API_URL%
echo - Admin Username: %ADMIN_USERNAME%
if defined EMAIL_TO_TEST echo - Testing Email: %EMAIL_TO_TEST%
if defined SKIP_HEALTH_CHECK echo - Health Check: Skipped
echo.

:: Run the Python script
echo Running Get User by Email Test...
echo.
python test_get_user_by_email.py%PYTHON_ARGS%

:: Check the exit code and provide appropriate feedback
if %ERRORLEVEL% EQU 0 (
    echo.
    echo ===== TEST COMPLETED SUCCESSFULLY =====
    echo The GET /api/admin/users/by-email/:email endpoint is working correctly!
    echo.
    if defined EMAIL_TO_TEST (
        echo Tested email: %EMAIL_TO_TEST%
    ) else (
        echo Comprehensive tests completed successfully.
    )
) else (
    echo.
    echo ===== TEST FAILED =====
    echo There were issues with the GET /api/admin/users/by-email/:email endpoint.
    echo Check the output above for details.
    echo.
    echo Common issues:
    echo - API server not running
    echo - Incorrect admin credentials
    echo - Network connectivity issues
    echo - User with specified email not found (if testing specific email)
)

echo.
echo ===== USAGE EXAMPLES =====
echo.
echo Test a specific email:
echo   %~nx0 --email user@example.com
echo.
echo Use custom admin credentials:
echo   %~nx0 --admin-username myadmin --admin-password mypassword
echo.
echo Use different API URL:
echo   %~nx0 --api-url http://production-server.com:3000
echo.
echo Skip health check:
echo   %~nx0 --skip-health-check
echo.
echo Run comprehensive tests (default):
echo   %~nx0
echo.

pause
exit /b %ERRORLEVEL%

:show_help
echo.
echo ===== GET USER BY EMAIL API TEST HELP =====
echo.
echo This script tests the GET /api/admin/users/by-email/:email endpoint
echo.
echo Usage: %~nx0 [OPTIONS]
echo.
echo Options:
echo   --email EMAIL           Test a specific email address
echo   --admin-username USER   Admin username (default: admin)
echo   --admin-password PASS   Admin password (default: admin@admin)
echo   --api-url URL          API base URL (default: http://localhost:3000)
echo   --skip-health-check    Skip the API health check
echo   --help                 Show this help message
echo.
echo Examples:
echo   %~nx0                                    Run comprehensive tests
echo   %~nx0 --email user@example.com          Test specific email
echo   %~nx0 --admin-username myadmin          Use custom admin username
echo   %~nx0 --api-url http://localhost:4000   Use different API URL
echo.
echo The script will:
echo 1. Check if the API server is running
echo 2. Login as admin user
echo 3. Test the GET /api/admin/users/by-email/:email endpoint
echo 4. Validate responses and error handling
echo.
pause
exit /b 0
