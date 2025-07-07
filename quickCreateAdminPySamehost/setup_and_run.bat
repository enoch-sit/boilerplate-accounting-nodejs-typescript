@echo off
REM setup_and_run.bat - Script to set up virtual environment and run create_users.py

echo Setting up virtual environment...
python -m venv venv

echo Activating virtual environment...
call venv\Scripts\activate.bat

echo Installing required packages...
pip install requests

echo Running the user creation script...
python create_users.py

echo Done!
pause