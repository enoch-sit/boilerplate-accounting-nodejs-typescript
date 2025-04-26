@echo off
setlocal

echo ===================================================
echo Simple Accounting Deployment Test Runner
echo ===================================================

rem Check if conda is installed
where conda >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Conda is not installed or not in PATH. Please run install.bat first.
    exit /b 1
)

rem Check if simple_auth_test environment exists
conda env list | find "simple_auth_test" >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Environment 'simple_auth_test' does not exist. Please run install.bat first.
    exit /b 1
)

rem Activate the environment
call conda activate simple_auth_test

echo.
echo Select deployment test options:
echo.
echo 1. Test local deployment (localhost:3000)
echo 2. Test Docker deployment
echo 3. Test custom URL
echo 4. Run full test suite (with admin tests)
echo.

set /p test_option="Enter option (1-4): "

set api_url=
set mailhog_url=
set use_real_email=n
set admin_test=n

if "%test_option%"=="1" (
    set api_url=http://localhost:3000
    set mailhog_url=http://localhost:8025
) else if "%test_option%"=="2" (
    set api_url=http://auth-service:3000
    set mailhog_url=http://mailhog:8025
) else if "%test_option%"=="3" (
    set /p api_url="Enter API URL (e.g., http://example.com:3000): "
) else if "%test_option%"=="4" (
    set /p api_url="Enter API URL (default: http://localhost:3000): "
    if "%api_url%"=="" set api_url=http://localhost:3000
    set admin_test=y
) else (
    echo Invalid option selected.
    exit /b 1
)

echo.
set /p use_mailhog="Use MailHog for email testing? (y/n): "
if /i "%use_mailhog%"=="y" (
    if "%mailhog_url%"=="" (
        set /p mailhog_url="Enter MailHog URL (e.g., http://localhost:8025): "
    )
) else (
    set mailhog_url=
)

echo.
set /p use_real_email="Use real email for verification? (y/n): "
if /i "%use_real_email%"=="y" (
    set /p email_address="Enter email address: "
) else (
    set email_address=
)

if "%test_option%" NEQ "4" (
    echo.
    set /p admin_test="Run admin API tests? (y/n): "
)

echo.
echo Running deployment tests...
echo.

rem Build the command
set cmd=python deploy_test.py

if not "%api_url%"=="" (
    set cmd=%cmd% --url "%api_url%"
)

if not "%email_address%"=="" (
    set cmd=%cmd% --email "%email_address%"
)

if not "%mailhog_url%"=="" (
    set cmd=%cmd% --mailhog-url "%mailhog_url%"
)

if /i "%admin_test%"=="y" (
    set cmd=%cmd% --admin-test true
)

rem Run the command
echo Executing: %cmd%
%cmd%

echo.
echo ===================================================
echo Test run completed
echo ===================================================

endlocal