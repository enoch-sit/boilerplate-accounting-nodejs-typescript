#!/bin/bash

echo "==================================================="
echo "Simple Accounting Deployment Test - Installation"
echo "==================================================="

# Check if conda is installed
if ! command -v conda &> /dev/null; then
    echo "Conda is not installed or not in PATH. Please install Miniconda or Anaconda."
    echo "Download from: https://docs.conda.io/en/latest/miniconda.html"
    exit 1
fi

# Check if simple_auth_test environment exists
if conda env list | grep -q "simple_auth_test"; then
    echo "Environment 'simple_auth_test' already exists."
    echo "To recreate it, run: conda env remove -n simple_auth_test"
    echo "Then run this script again."
    
    read -p "Do you want to update the existing environment? (y/n): " update_env
    if [[ "$update_env" == "y" || "$update_env" == "Y" ]]; then
        echo "Updating environment..."
        source "$(conda info --base)/etc/profile.d/conda.sh"
        conda activate simple_auth_test
        pip install requests
        if [ $? -ne 0 ]; then
            echo "Failed to install packages. Trying with conda..."
            conda install -y requests
        fi
    fi
else
    echo "Creating new conda environment 'simple_auth_test'..."
    conda create -y -n simple_auth_test python=3.9
    if [ $? -ne 0 ]; then
        echo "Failed to create conda environment."
        exit 1
    fi
    
    echo "Installing required packages..."
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate simple_auth_test
    pip install requests
    if [ $? -ne 0 ]; then
        echo "Failed to install packages with pip. Trying with conda..."
        conda install -y requests
    fi
fi

# Verify installation
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate simple_auth_test
python -c "import requests; print('Package requests is installed correctly')" &> /dev/null
if [ $? -ne 0 ]; then
    echo "ERROR: Package 'requests' could not be installed. Please install it manually:"
    echo "  conda activate simple_auth_test"
    echo "  pip install requests"
    echo "  - OR -"
    echo "  conda install -c conda-forge requests"
    exit 1
else
    echo "Package 'requests' verified successfully."
fi

echo "==================================================="
echo "Installation completed successfully!"
echo "==================================================="
echo "To run the deployment tests:"
echo "1. Run ./start.sh"
echo "2. Follow the on-screen instructions"
echo "==================================================="