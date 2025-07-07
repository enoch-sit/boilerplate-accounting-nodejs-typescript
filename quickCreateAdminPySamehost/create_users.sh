#!/bin/bash
# User Creation Shell Script
# This script runs the create_users.py script to create admin, supervisor, and regular users

echo "===== User Creation Utility ====="
echo "This script will create default users with different roles in the database."

# Check if Python is installed
if ! command -v python3 &>/dev/null; then
    echo "Error: Python 3 is not installed or not in PATH"
    echo "Please install Python 3.7+ and try again"
    exit 1
fi

# Check if virtual environment exists, if not create it
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate the virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Install required packages in the virtual environment
echo "Installing required packages..."
pip install requests

# Run the Python script
echo ""
echo "Running User Creation Script..."
echo ""
python create_users.py

echo ""
if [ $? -eq 0 ]; then
    echo "User creation completed successfully!"
else
    echo "Error occurred during user creation."
fi

# Deactivate the virtual environment
deactivate

read -p "Press Enter to continue..."