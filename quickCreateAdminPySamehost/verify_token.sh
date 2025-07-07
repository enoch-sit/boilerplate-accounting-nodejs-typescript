#!/bin/bash

# Verify Token Shell Script
# This script runs verify_token.py to verify a JWT token

echo "===== JWT Token Verification Utility ====="
echo "This script will verify a JWT token using a secret key."

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is not installed or not in PATH"
    echo "Please install Python 3.7+ and try again"
    exit 1
fi

# Run the Python script directly (no additional dependencies needed)
echo ""
echo "Running Token Verification Script..."
echo ""
python3 verify_token.py

echo ""
if [ $? -eq 0 ]; then
    echo "Token verification completed!"
else
    echo "Error occurred during token verification."
fi

echo "Press any key to continue..."
read -n 1 -s
