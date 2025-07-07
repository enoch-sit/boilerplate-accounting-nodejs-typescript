#!/bin/bash

# Get Token Shell Script
# This script runs get_token.py to retrieve a JWT token for a user

echo "===== JWT Token Retrieval Utility ====="
echo "This script will log in as a user and retrieve their JWT token."

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
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
echo "Running Token Retrieval Script..."
echo ""
python3 get_token.py

echo ""
if [ $? -eq 0 ]; then
    echo "Token retrieval completed successfully!"
else
    echo "Error occurred during token retrieval."
fi

# Deactivate the virtual environment
deactivate

echo "Press any key to continue..."
read -n 1 -s
