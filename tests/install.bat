@echo off
setlocal enabledelayedexpansion

echo ===================================================
echo Simple Accounting Deployment Test - Installation
echo ===================================================

rem Check if conda is installed
where conda >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Conda is not installed or not in PATH. Please install Miniconda or Anaconda.
    echo Download from: https://docs.conda.io/en/latest/miniconda.html
    exit /b 1
)

rem Check if simple_auth_test environment exists
conda env list | find "simple_auth_test" >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo Environment 'simple_auth_test' already exists.
    echo To recreate it, run: conda env remove -n simple_auth_test
    echo Then run this script again.
    
    set /p update_env="Do you want to update the existing environment? (y/n): "
    if /i "!update_env!"=="y" (
        echo Updating environment...
        call conda activate simple_auth_test
        pip install requests
        if %ERRORLEVEL% NEQ 0 (
            echo Failed to install packages. Trying with conda...
            conda install -y requests
        )
    )
) else (
    echo Creating new conda environment 'simple_auth_test'...
    call conda create -y -n simple_auth_test python=3.9
    if %ERRORLEVEL% NEQ 0 (
        echo Failed to create conda environment.
        exit /b 1
    )
    
    echo Installing required packages...
    call conda activate simple_auth_test
    pip install requests
    if %ERRORLEVEL% NEQ 0 (
        echo Failed to install packages with pip. Trying with conda...
        conda install -y requests
    )
)

rem Verify installation
call conda activate simple_auth_test
python -c "import requests; print('Package requests is installed correctly')" >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Package 'requests' could not be installed. Please install it manually:
    echo   conda activate simple_auth_test
    echo   pip install requests
    echo   - OR -
    echo   conda install -c conda-forge requests
    exit /b 1
) else (
    echo Package 'requests' verified successfully.
)

echo ===================================================
echo Installation completed successfully!
echo ===================================================
echo To run the deployment tests:
echo 1. Run start.bat
echo 2. Follow the on-screen instructions
echo ===================================================

endlocal